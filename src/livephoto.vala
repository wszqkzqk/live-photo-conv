/* Copyright 2024 Zhou Qiankang <wszqkzqk@qq.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
*/

/**
 * Represents a live photo.
 *
 * This class provides a set of functions to extract the main image and video from a live photo.
 * Also, it can split the video into images.
 */
public abstract class LivePhotoConv.LivePhoto : Object {

    // The tag `....ftyp` of MP4 header.
    const uint8[] MP4_VIDEO_HEADER = {'f', 't', 'y', 'p'};
    const int PATTERN_LENGTH = MP4_VIDEO_HEADER.length;
    // The feature of MP4: there is extra 4 bytes of size before the `ftyp` tag.
    // (It's `....ftyp` instead of `ftyp`)
    // See also: http://www.ftyps.com/
    const int LENGTH_BEFORE_FTYP = 4;

    protected string basename;
    protected string basename_no_ext;
    protected string extension_name;
    protected string filename;
    protected GExiv2.Metadata metadata;
    protected string dest_dir;
    protected int64 video_offset;
    protected Tree<string?, string?> xmp_map;

    public bool make_backup {
        get;
        set;
        default = false;
    }
    public bool export_original_metadata {
        get;
        set;
        default = true;
    }
    public FileCreateFlags file_create_flags {
        get;
        set;
        default = FileCreateFlags.REPLACE_DESTINATION;
    }

    /**
     * Creates a new instance of the LivePhoto class.
     *
     * The path to the **live photo** file is required.
     * The destination directory for the converted live photo is optional.
     * If not provided, the directory of the input file will be used.
     * The file creation flags can be specified to control the behavior of the file creation process.
     * By default, the destination file will be replaced if it already exists.
     * A backup of the destination file can be created before replacing it.
     * The original metadata of the live photo can be exported.
     *
     * @param filename The path to the live photo file.
     * @param dest_dir The destination directory for the converted live photo. If not provided, the directory of the input file will be used.
     * @throws Error if an error occurs while retrieving the offset.
    */
    protected LivePhoto (string filename, string? dest_dir = null) throws Error {
        this.metadata = new GExiv2.Metadata ();
        this.metadata.open_path (filename);

        // Copy the XMP metadata to the map
        this.xmp_map = new Tree<string?, string?> ((a, b) => {return strcmp (a, b);});
        foreach (unowned var tag in this.metadata.get_xmp_tags ()) {
            try {
                this.xmp_map.insert (tag, this.metadata.try_get_tag_string (tag));
            } catch (Error e) {
                Reporter.warning ("XMPWarning", "Cannot get the value of the XMP tag %s: %s", tag, e.message);
            }
        }
        // Clear some XMP metadata to export the images which are not live photos
        this.clear_live_xmp_tags ();

        this.filename = filename;
        this.basename = Path.get_basename (filename);
        var last_dot = this.basename.last_index_of_char ('.');
        if (last_dot == -1) {
            this.basename_no_ext = this.basename;
            this.extension_name = "jpg"; // Default extension name
        } else {
            this.basename_no_ext = this.basename[:last_dot];
            if (last_dot + 1 < this.basename.length) {
                this.extension_name = this.basename[last_dot + 1:];
            } else {
                this.extension_name = "jpg"; // Default extension name
            }
        }
        if (dest_dir != null) {
            this.dest_dir = dest_dir;
        } else {
            this.dest_dir = Path.get_dirname (filename);
        }

        this.video_offset = this.get_video_offset ();
        if (this.video_offset < 0) {
            throw new NotLivePhotosError.OFFSET_NOT_FOUND_ERROR ("The offset of the video data in the live photo is not found.");
        }
    }

    /**
     * Get the offset of the video data in the live photo.
     *
     * The offset can be used to split the video into images.
     * This function first tries to get the offset from the XMP metadata.
     * If the offset is not found, it searches for the MP4 header in the live photo.
     *
     * @throws Error if an error occurs while retrieving the offset.
     *
     * @return the offset of the video data in the live photo， if the offset is not found, return value < 0.
    */
    inline int64 get_video_offset () throws Error {
        // Get the offset of the video data from the XMP metadata
        var tag_value = this.xmp_map.lookup ("Xmp.GCamera.MotionPhotoOffset");
        if (tag_value == null) {
            // Fallback to the old standard
            tag_value = this.xmp_map.lookup ("Xmp.GCamera.MicroVideoOffset");
        }
        if (tag_value != null) {
            int64 reverse_offset = int64.parse (tag_value);
            if (reverse_offset > 0) {
                var file_size = File.new_for_commandline_arg  (this.filename)
                    .query_info ("standard::size", FileQueryInfoFlags.NONE)
                    .get_size ();
                return file_size - reverse_offset;
            }
        }

        // If the XMP metadata does not contain the video offset, search for the video tag in the live photo
        Reporter.warning_puts ("XMPOffsetNotFoundWarning",
        "The XMP metadata does not contain the video offset. Searching for the video tag in the live photo.");

        return this.get_video_offset_fallback ();
    }

    /**
     * Gets the video offset in the live photo using a fallback method.
     *
     * This method searches for the `ftyp` tag in the MP4 header to determine the offset of the video data.
     * It reads the file in chunks and checks for the tag, handling boundary crossing between chunks.
     *
     * @return The offset of the video data in the live photo.
     * @throws Error if there is an issue reading the file.
    */
    inline int64 get_video_offset_fallback () throws Error {
        int64 offset = -1; // Record the offset of the video data in the live photo
        var file = File.new_for_commandline_arg (this.filename);
        var input_stream = file.read ();
        ssize_t bytes_read;
        int64 global_pos = 0; // Global byte position
        uint8[] buffer = new uint8[Utils.BUFFER_SIZE];

        // KMP algorithm preparation: Use MP4_VIDEO_HEADER directly as the pattern to build the lps array
        int[] lps = new int[PATTERN_LENGTH];
        lps[0] = 0;
        int len = 0;
        for (int i = 1; i < PATTERN_LENGTH; i += 1) {
            while (len > 0 && MP4_VIDEO_HEADER[i] != MP4_VIDEO_HEADER[len]) {
                len = lps[len - 1];
            }
            if (MP4_VIDEO_HEADER[i] == MP4_VIDEO_HEADER[len]) {
                len += 1;
            }
            lps[i] = len;
        }

        int j = 0; // Pattern index
        while ((bytes_read = input_stream.read (buffer)) > 0) {
            for (int i = 0; i < bytes_read; i += 1) {
                while (j > 0 && buffer[i] != MP4_VIDEO_HEADER[j]) {
                    j = lps[j - 1];
                }
                if (buffer[i] == MP4_VIDEO_HEADER[j]) {
                    j += 1;
                }
                if (j == PATTERN_LENGTH) {
                    offset = global_pos + i - PATTERN_LENGTH + 1;
                    break;
                }
            }
            if (offset != -1) {
                break;
            }
            global_pos += bytes_read;
        }
        return offset - LENGTH_BEFORE_FTYP;
    }
    
    /**
     * Export the main image of the live photo.
     *
     * The destination path for the exported main image can be specified.
     * If not provided, a default path will be used.
     *
     * @param dest The destination path for the exported main image. If null, a default path will be used.
     * @throws Error if there is an error during the export process.
     * @return The path of the exported main image.
    */
    public string export_main_image (string? dest = null) throws Error {
        // Export the bytes before `video_offset`
        var file = File.new_for_commandline_arg  (this.filename);
        var input_stream = file.read ();
        string main_image_filename;
        if (dest != null) {
            main_image_filename = dest;
        } else if (this.basename.has_prefix ("MVIMG")) {
            // The main image of a live photo is named as `IMG_YYYYMMDD_HHMMSS.xxx`
            main_image_filename = Path.build_filename (this.dest_dir, "IMG" + this.basename[5:]);
        } else {
            // If the original image is xxx.yyy, the main image is xxx_0.yyy
            main_image_filename = Path.build_filename (this.dest_dir, this.basename_no_ext + "_0." + this.extension_name);
        }

        var output_stream = File.new_for_commandline_arg  (main_image_filename).replace (null, make_backup, file_create_flags);
        // Write the bytes before `video_offset` to the main image file
        Utils.write_stream_before (input_stream, output_stream, this.video_offset);

        Reporter.info_puts ("Exported main image", main_image_filename);

        if (export_original_metadata) {
            // Copy the metadata from the live photo to the main image
            try {
                this.metadata.save_file (main_image_filename);
            } catch (Error e) {
                throw new ExportError.METADATA_EXPORT_ERROR ("Cannot export the metadata to %s: %s", main_image_filename, e.message);
            }
        }

        return (owned) main_image_filename;
    }

    /**
     * Export the video of the live photo.
     *
     * The destination path for the exported video can be specified.
     * If not provided, a default path will be used.
     * The video is exported from the live photo and saved as an MP4 file.
     *
     * @param dest The destination path for the exported video. If not provided, a default path will be used.
     * @throws Error if there is an error during the export process.
     * @return The path of the exported video file.
    */
    public string export_video (string? dest = null) throws Error {
        /* Export the video of the live photo. */
        // Export the bytes after `video_offset`
        var file = File.new_for_commandline_arg  (this.filename);
        var input_stream = file.read ();
        string video_filename;
        if (dest != null) {
            video_filename = dest;
        } else if (this.basename.has_prefix ("MVIMG")) {
            // The video of a live photo is named as `VID_YYYYMMDD_HHMMSS.mp4`
            video_filename = Path.build_filename (this.dest_dir, "VID" + this.basename_no_ext[5:] + ".mp4");
        } else if (this.basename.has_prefix ("IMG")) {
            // If the original image is IMG_YYYYMMDD_HHMMSS.xxx, the video is VID_YYYYMMDD_HHMMSS.mp4
            video_filename = Path.build_filename (this.dest_dir, "VID" + this.basename_no_ext[3:] + ".mp4");
        } else {
            video_filename = Path.build_filename (this.dest_dir, "VID_" + this.basename_no_ext + ".mp4");
        }

        var output_stream = File.new_for_commandline_arg (video_filename).replace (null, make_backup, file_create_flags);
        // Write the bytes after `video_offset` to the video file
        input_stream.seek (this.video_offset, SeekType.SET);
        Utils.write_stream (input_stream, output_stream);

        Reporter.info_puts ("Exported video file", video_filename);

        return (owned) video_filename;
    }

    /**
     * Repairs the video offset metadata for the current file.
     *
     * This function attempts to repair the video offset metadata by either using
     * a fallback method or the standard method to retrieve the offset. If the
     * offset is valid (non-negative), it updates the relevant metadata tags and
     * saves the changes to the file.
     *
     * @param force If true, forces the use of the fallback method to get the video offset.
     * @param manual_video_size If greater than 0, uses this value as the video size instead of calculating it.
     * @throws Error if there is an issue with retrieving the video offset or saving the metadata.
    */
    public void repair_live_metadata (bool force = false, uint manual_video_size = 0) throws Error {
        GExiv2.Metadata.try_register_xmp_namespace ("http://ns.google.com/photos/1.0/camera/", "GCamera");
        GExiv2.Metadata.try_register_xmp_namespace ("http://ns.google.com/photos/1.0/container/", "Container");
        GExiv2.Metadata.try_register_xmp_namespace ("http://ns.google.com/photos/1.0/container/item/", "Item");

        var file_size = File.new_for_commandline_arg  (this.filename)
            .query_info ("standard::size", FileQueryInfoFlags.NONE)
            .get_size ();

        int64 reverse_offset;

        if (manual_video_size > 0) {
            reverse_offset = manual_video_size;
        } else if (force) {
            reverse_offset = file_size - this.get_video_offset_fallback ();
        } else {
            // Check whether the current video offset is valid
            var file = File.new_for_commandline_arg (this.filename);
            var input_stream = file.read ();
            input_stream.seek (this.video_offset + LENGTH_BEFORE_FTYP, SeekType.SET);
            uint8[] header = new uint8[PATTERN_LENGTH];
            ssize_t read_bytes = input_stream.read (header, null);
            bool header_valid = (read_bytes == PATTERN_LENGTH);
            if (header_valid) {
                for (int i = 0; i < PATTERN_LENGTH; i += 1) {
                    if (header[i] != MP4_VIDEO_HEADER[i]) {
                        header_valid = false;
                        break;
                    }
                }
            }
            if (header_valid) {
                reverse_offset = file_size - this.video_offset;
            } else {
                Reporter.info_puts ("Info", "Broken video offset detected. Trying to repair...");
                reverse_offset = file_size - this.get_video_offset_fallback ();
            }
        }

        if (reverse_offset < 0) {
            throw new NotLivePhotosError.OFFSET_NOT_FOUND_ERROR ("The offset of the video data in the live photo is not found.");
        }

        var offset_string = reverse_offset.to_string ();

        string presentation_timestamp_us_to_write = "0";
        // this.xmp_map contains tags loaded in the constructor
        var original_motion_photo_ts = this.xmp_map.lookup("Xmp.Camera.MotionPhotoPresentationTimestampUs");
        var original_gcamera_ts = this.xmp_map.lookup("Xmp.GCamera.MicroVideoPresentationTimestampUs");

        if (original_motion_photo_ts != null && original_motion_photo_ts != "") {
            presentation_timestamp_us_to_write = original_motion_photo_ts;
        } else if (original_gcamera_ts != null && original_gcamera_ts != "") {
            presentation_timestamp_us_to_write = original_gcamera_ts;
        }

        // Set GCamera (old standard) tags
        this.xmp_map.insert ("Xmp.GCamera.MicroVideo", "1");
        this.xmp_map.insert ("Xmp.GCamera.MicroVideoVersion", "1");
        this.xmp_map.insert ("Xmp.GCamera.MicroVideoOffset", offset_string);
        this.xmp_map.insert ("Xmp.GCamera.MicroVideoPresentationTimestampUs", presentation_timestamp_us_to_write);

        // Add/Update new MotionPhoto standard tags in xmp_map
        this.xmp_map.insert ("Xmp.GCamera.MotionPhoto", "1");
        this.xmp_map.insert ("Xmp.GCamera.MotionPhotoVersion", "1");
        this.xmp_map.insert ("Xmp.GCamera.MotionPhotoPresentationTimestampUs", presentation_timestamp_us_to_write);
        // Set Container and Item tags for MotionPhoto
        this.metadata.try_set_xmp_tag_struct ("Xmp.Container.Directory", GExiv2.StructureType.SEQ);
        this.metadata.try_set_tag_string ("Xmp.Container.Directory[1]/Container:Item", "type=Struct");
        this.metadata.try_set_tag_string ("Xmp.Container.Directory[2]/Container:Item", "type=Struct");

        // Add Container and Item tags for MotionPhoto
        // Item 1: Primary Image (assuming JPEG based on typical output)
        var image_mime_type = "image/jpeg"; // Default, could be refined based on actual extension
        if (this.extension_name.down () == "heic" || this.extension_name.down () == "heif") {
            image_mime_type = "image/heic";
        } else if (this.extension_name.down () == "avif") {
            image_mime_type = "image/avif";
        }
        this.xmp_map.insert ("Xmp.Container.Directory[1]/Item:Mime", image_mime_type);
        this.xmp_map.insert ("Xmp.Container.Directory[1]/Item:Semantic", "Primary");
        // Item:Padding: For JPEG, optional (can be 0 or omitted). For HEIC/AVIF, must be 8.
        // This example assumes JPEG or doesn't set padding. A more robust solution would check image_mime_type.
        // if (image_mime_type == "image/heic" || image_mime_type == "image/avif") {
        //    this.xmp_map.insert ("Xmp.Container.Directory[1]/Item:Padding", "8");
        // }

        // Item 2: Video (assuming MP4)
        this.xmp_map.insert ("Xmp.Container.Directory[2]/Item:Mime", "video/mp4");
        this.xmp_map.insert ("Xmp.Container.Directory[2]/Item:Semantic", "MotionPhoto");
        this.xmp_map.insert ("Xmp.Container.Directory[2]/Item:Length", offset_string); // offset_string is reverse_offset, i.e., video_size

        // Restore the XMP metadata for the live photo
        Error? metadata_error = null;
        this.xmp_map.foreach ((key, value) => {
            try {
                this.metadata.try_set_tag_string (key, value);
                return false;
            } catch (Error e) {
                metadata_error = e;
                return true;
            }
        });
        if (metadata_error != null) {
            throw new ExportError.METADATA_EXPORT_ERROR ("Cannot set the XMP metadata: %s", metadata_error.message);
        }

        this.metadata.save_file (this.filename);

        // Clear some XMP metadata to export the images which are not live photos
        this.clear_live_xmp_tags ();

        // Refresh the video_offset field
        this.video_offset = file_size - reverse_offset;

        Reporter.info ("Repaired", "The reverse video offset metadata is set to %s", offset_string);
    }

    inline void clear_live_xmp_tags () {
        try {
            // Clear GCamera (old standard) tags
            this.metadata.try_clear_tag ("Xmp.GCamera.MicroVideo");
            this.metadata.try_clear_tag ("Xmp.GCamera.MicroVideoVersion");
            this.metadata.try_clear_tag ("Xmp.GCamera.MicroVideoOffset");
            this.metadata.try_clear_tag ("Xmp.GCamera.MicroVideoPresentationTimestampUs");

            // Clear Camera (new standard) tags
            this.metadata.try_clear_tag ("Xmp.GCamera.MotionPhoto");
            this.metadata.try_clear_tag ("Xmp.GCamera.MotionPhotoVersion");
            this.metadata.try_clear_tag ("Xmp.GCamera.MotionPhotoPresentationTimestampUs");

            // Clearing structured Container:Directory tags might require specific path handling
            // or clearing the parent Xmp.Container.Directory tag if supported.
            // For simplicity, we are clearing the main identifiable tags.
            this.metadata.try_clear_tag ("Xmp.Container.Directory");
        } catch (Error e) {
            Reporter.warning ("XMPWarning", "Cannot clear the XMP metadata: %s", e.message);
        }
    }

    public abstract void splites_images_from_video (string? output_format = null, string? dest_dir = null, int jobs = 0) throws Error;
}


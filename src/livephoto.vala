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
        ensure_exiv2_init ();
        this.metadata = new GExiv2.Metadata ();
        this.metadata.open_path (filename);

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
        if (this.video_offset <= 0) {
            throw new NotLivePhotosError.OFFSET_NOT_FOUND_ERROR ("The offset of the video data in the live photo is not found.");
        }
    }

    /**
     * Creates a new instance of LivePhoto with the requested backend.
     *
     * The concrete backend class is chosen by the factory; with
     * {@link Backend.AUTO} GStreamer is preferred when built in.
     *
     * @param filename The path to the live photo file.
     * @param dest_dir The destination directory, or null to use the input file's directory.
     * @param backend The video processing backend to use.
     * @throws Error if the requested backend is unavailable or the live photo cannot be parsed.
     * @return The new LivePhoto instance.
     */
    public static LivePhoto create (string filename, string? dest_dir = null,
                                    Backend backend = AUTO) throws Error {
#if ENABLE_GST
        if (backend != Backend.FFMPEG)
            return new LivePhotoGst (filename, dest_dir);
#endif
        if (backend == Backend.GST)
            throw new ExportError.GST_ERROR ("GStreamer backend requested but not built in");
        return new LivePhotoFFmpeg (filename, dest_dir);
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
        string? tag_value = null;
        try {
            if (this.metadata.has_tag ("Xmp.Container.Directory[2]/Container:Item/Item:Length")) {
                tag_value = this.metadata.get_tag_string ("Xmp.Container.Directory[2]/Container:Item/Item:Length");
            } else if (this.metadata.has_tag ("Xmp.GCamera.MicroVideoOffset")) {
                // Fallback to the old standard
                tag_value = this.metadata.get_tag_string ("Xmp.GCamera.MicroVideoOffset");
            }
        } catch {} // An unreadable tag is treated as absent: fall through to the scan
        if (tag_value != null) {
            int64 reverse_offset = int64.parse (tag_value);
            if (reverse_offset > 0) {
                var file_size = File.new_for_commandline_arg  (this.filename)
                    .query_info ("standard::size", FileQueryInfoFlags.NONE)
                    .get_size ();
                var offset = file_size - reverse_offset;
                if (offset > 0) {
                    return offset;
                }
                // An XMP offset beyond the file size is garbage; fall through to the scan
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
     * Returns metadata for exported files: the source's metadata with XMP
     * cleared, so that extracted images are not marked as live photos.
     *
     * @return A fresh metadata copy for export use.
     * @throws Error if the source file's metadata cannot be read.
     */
    internal GExiv2.Metadata metadata_for_export () throws Error {
        var meta = new GExiv2.Metadata ();
        meta.open_path (this.filename);
        meta.clear_xmp ();
        return meta;
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
                this.metadata_for_export ().save_file (main_image_filename);
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
        var file_size = File.new_for_commandline_arg  (this.filename)
            .query_info ("standard::size", FileQueryInfoFlags.NONE)
            .get_size ();

        int64 reverse_offset;

        if (manual_video_size > 0) {
            reverse_offset = manual_video_size;
        } else if (force) {
            var offset = this.get_video_offset_fallback ();
            if (offset < 0) {
                throw new NotLivePhotosError.OFFSET_NOT_FOUND_ERROR ("The offset of the video data in the live photo is not found.");
            }
            reverse_offset = file_size - offset;
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
                var offset = this.get_video_offset_fallback ();
                if (offset < 0) {
                    throw new NotLivePhotosError.OFFSET_NOT_FOUND_ERROR ("The offset of the video data in the live photo is not found.");
                }
                reverse_offset = file_size - offset;
            }
        }

        if (reverse_offset < 0) {
            throw new NotLivePhotosError.OFFSET_NOT_FOUND_ERROR ("The offset of the video data in the live photo is not found.");
        }

        var offset_string = reverse_offset.to_string ();

        // Preserve an existing presentation timestamp if there is one
        string presentation_timestamp_us_to_write = "0";
        if (this.metadata.has_tag ("Xmp.GCamera.MotionPhotoPresentationTimestampUs")) {
            var ts = this.metadata.get_tag_string ("Xmp.GCamera.MotionPhotoPresentationTimestampUs");
            if (ts != null && ts != "")
                presentation_timestamp_us_to_write = ts;
        } else if (this.metadata.has_tag ("Xmp.GCamera.MicroVideoPresentationTimestampUs")) {
            var ts = this.metadata.get_tag_string ("Xmp.GCamera.MicroVideoPresentationTimestampUs");
            if (ts != null && ts != "")
                presentation_timestamp_us_to_write = ts;
        }

        // Set GCamera (old standard) tags
        this.metadata.set_tag_string ("Xmp.GCamera.MicroVideo", "1");
        this.metadata.set_tag_string ("Xmp.GCamera.MicroVideoVersion", "1");
        this.metadata.set_tag_string ("Xmp.GCamera.MicroVideoOffset", offset_string);
        this.metadata.set_tag_string ("Xmp.GCamera.MicroVideoPresentationTimestampUs", presentation_timestamp_us_to_write);

        // Set MotionPhoto (new standard) tags
        this.metadata.set_tag_string ("Xmp.GCamera.MotionPhoto", "1");
        this.metadata.set_tag_string ("Xmp.GCamera.MotionPhotoVersion", "1");
        this.metadata.set_tag_string ("Xmp.GCamera.MotionPhotoPresentationTimestampUs", presentation_timestamp_us_to_write);

        // Set Container and Item tags for MotionPhoto. Only create missing
        // nodes: re-declaring an existing struct wipes its children.
        if (!this.metadata.has_tag ("Xmp.Container.Directory")) {
            this.metadata.set_xmp_tag_struct ("Xmp.Container.Directory", GExiv2.StructureType.SEQ);
        }
        if (!this.metadata.has_tag ("Xmp.Container.Directory[1]/Container:Item")) {
            this.metadata.set_tag_string ("Xmp.Container.Directory[1]", "type=Struct");
            this.metadata.set_tag_string ("Xmp.Container.Directory[1]/Container:Item", "type=Struct");
        }
        if (!this.metadata.has_tag ("Xmp.Container.Directory[2]/Container:Item")) {
            this.metadata.set_tag_string ("Xmp.Container.Directory[2]", "type=Struct");
            this.metadata.set_tag_string ("Xmp.Container.Directory[2]/Container:Item", "type=Struct");
        }

        // Item 1: Primary Image (assuming JPEG based on typical output)
        var image_mime_type = "image/jpeg"; // Default, could be refined based on actual extension
        if (this.extension_name.down () == "heic" || this.extension_name.down () == "heif") {
            image_mime_type = "image/heic";
        } else if (this.extension_name.down () == "avif") {
            image_mime_type = "image/avif";
        }
        this.metadata.set_tag_string ("Xmp.Container.Directory[1]/Container:Item/Item:Mime", image_mime_type);
        this.metadata.set_tag_string ("Xmp.Container.Directory[1]/Container:Item/Item:Semantic", "Primary");
        // Item:Padding: For JPEG, optional (can be 0 or omitted). For HEIC/AVIF, must be 8.
        // This example assumes JPEG or doesn't set padding. A more robust solution would check image_mime_type.
        // if (image_mime_type == "image/heic" || image_mime_type == "image/avif") {
        //    this.metadata.set_tag_string ("Xmp.Container.Directory[1]/Container:Item/Item:Padding", "8");
        // }
        // Item 2: Video (assuming MP4)
        this.metadata.set_tag_string ("Xmp.Container.Directory[2]/Container:Item/Item:Mime", "video/mp4");
        this.metadata.set_tag_string ("Xmp.Container.Directory[2]/Container:Item/Item:Semantic", "MotionPhoto");
        this.metadata.set_tag_string ("Xmp.Container.Directory[2]/Container:Item/Item:Length", offset_string); // offset_string is reverse_offset, i.e., video_size

        // save_file returns false on encode/write failure
        if (!this.metadata.save_file (this.filename)) {
            throw new ExportError.METADATA_EXPORT_ERROR ("Cannot save the metadata to %s", this.filename);
        }

        // Refresh the video_offset field; the metadata rewrite may change the file size
        file_size = File.new_for_commandline_arg (this.filename)
            .query_info ("standard::size", FileQueryInfoFlags.NONE)
            .get_size ();
        this.video_offset = file_size - reverse_offset;

        Reporter.info ("Repaired", "The reverse video offset metadata is set to %s", offset_string);
    }

    /**
     * Async version of {@link repair_live_metadata}.
     *
     * @param force If true, forces the use of the fallback method to get the video offset.
     * @param manual_video_size If greater than 0, uses this value as the video size instead of calculating it.
     * @throws Error if there is an issue with retrieving the video offset or saving the metadata.
     */
    public async void repair_live_metadata_async (bool force = false, uint manual_video_size = 0) throws Error {
        SourceFunc callback = repair_live_metadata_async.callback;
        Error? repair_error = null;
        var thread = new Thread<void> ("live-photo-repair", () => {
            try {
                this.repair_live_metadata (force, manual_video_size);
            } catch (Error e) {
                repair_error = e;
            }
            Idle.add ((owned) callback);
        });
        yield;
        thread.join ();
        if (repair_error != null)
            throw (owned) repair_error;
    }

    /**
     * Async composite extraction: runs multiple extract operations in sequence.
     *
     * Pass null for dest params to use auto-generated file names based on
     * the dest_dir provided in the constructor.
     *
     * @param do_image Whether to export the main image.
     * @param do_video Whether to export the video.
     * @param do_long_exposure Whether to generate a long exposure image.
     * @param do_frames Whether to split images from the video.
     * @param long_exposure_dest The destination path for the long exposure image, or null to use an auto-generated path.
     * @param img_format The output image format for the split frames, or null.
     * @param threads The number of threads to use for frame extraction.
     * @throws Error if there is an error during the extraction process.
     */
    public async void extract_items_async (bool do_image, bool do_video,
                                            bool do_long_exposure, bool do_frames,
                                            string? long_exposure_dest,
                                            string? img_format = null, int threads = 0) throws Error {
        SourceFunc callback = extract_items_async.callback;
        Error? extract_error = null;
        var thread = new Thread<void> ("live-photo-extract", () => {
            try {
                if (do_image)
                    this.export_main_image ();
                if (do_video)
                    this.export_video ();
                if (do_long_exposure && long_exposure_dest != null)
                    this.generate_long_exposure (long_exposure_dest);
                if (do_frames)
                    this.split_images_from_video (img_format, null, threads);
            } catch (Error e) {
                extract_error = e;
            }
            Idle.add ((owned) callback);
        });
        yield;
        thread.join ();
        if (extract_error != null)
            throw extract_error;
    }

    /**
     * Generate a long exposure image from the live photo's video frames.
     *
     * This method stacks the video frames to create a long exposure effect
     * and writes the result to the specified path.
     *
     * @param dest_path The destination path for the generated long exposure image.
     * @throws Error if an error occurs during generation.
     */
    public abstract void generate_long_exposure (string dest_path) throws Error;

    /**
     * Split the video into individual images.
     *
     * The video of the live photo is split into frames, which are saved
     * to the destination directory with the specified output format.
     * If the output format is not provided, the default extension name
     * of the live photo will be used. The filenames are generated based
     * on the basename of the live photo.
     *
     * @param output_format The format of the output images. If not provided,
     *                      the default extension name will be used.
     * @param dest_dir The destination directory where the images will be saved.
     *                 If not provided, the default destination directory will be used.
     * @param threads The number of threads to use for parallel processing.
     *                The exact behavior depends on the backend implementation.
     * @throws Error if an error occurs during splitting.
     */
    public abstract void split_images_from_video (string? output_format = null, string? dest_dir = null, int threads = 0) throws Error;
}

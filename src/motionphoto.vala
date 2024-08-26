/* motionphoto.vala
 *
 * Copyright 2024 Zhou Qiankang <wszqkzqk@qq.com>
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
 * @class MotionPhotoConv.MotionPhoto
 *
 * Represents a motion photo.
 *
 * This class provides a set of functions to extract the main image and video from a motion photo.
 * Also, it can split the video into images.
 */
public abstract class MotionPhotoConv.MotionPhoto : Object {

    protected string basename;
    protected string basename_no_ext;
    protected string extension_name;
    protected string filename;
    protected GExiv2.Metadata metadata;
    protected string dest_dir;
    protected int64 video_offset;
    protected bool make_backup;
    protected bool export_original_metadata;
    protected FileCreateFlags file_create_flags;
    // string xmp;

    /**
     * Creates a new instance of the MotionPhoto class.
     *
     * The path to the **motion photo** file is required.
     * The destination directory for the converted motion photo is optional.
     * If not provided, the directory of the input file will be used.
     * The file creation flags can be specified to control the behavior of the file creation process.
     * By default, the destination file will be replaced if it already exists.
     * A backup of the destination file can be created before replacing it.
     * The original metadata of the motion photo can be exported.
     *
     * @param filename The path to the motion photo file.
     * @param dest_dir The destination directory for the converted motion photo. If not provided, the directory of the input file will be used.
     * @param export_metadata Whether to export the original metadata of the motion photo. Default is true.
     * @throws Error if an error occurs while retrieving the offset.
     */
    protected MotionPhoto (string filename, string? dest_dir = null, bool export_metadata = true,
                        FileCreateFlags file_create_flags = FileCreateFlags.REPLACE_DESTINATION, bool make_backup = false) throws Error {
        this.metadata = new GExiv2.Metadata ();
        this.metadata.open_path (filename);
        this.make_backup = make_backup;
        this.file_create_flags = file_create_flags;
        // Get XMP metadata of the image
        // this.xmp = this.metadata.try_get_xmp_packet ();

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
            throw new NotMotionPhotosError.OFFSET_NOT_FOUND_ERROR ("The offset of the video data in the motion photo is not found.");
        }
        // Remove the XMP metadata of the main image since it is not a motion photo anymore
        // MUST after `get_video_offset` because `get_video_offset` may use the XMP metadata
        this.metadata.clear_xmp ();
        this.export_original_metadata = export_metadata;
    }

    /**
     * Get the offset of the video data in the motion photo.
     *
     * The offset can be used to split the video into images.
     * This function first tries to get the offset from the XMP metadata.
     * If the offset is not found, it searches for the MP4 header in the motion photo.
     *
     * @throws Error if an error occurs while retrieving the offset.
     *
     * @returns the offset of the video data in the motion photo， if the offset is not found, return value < 0.
     */
    inline int64 get_video_offset () throws Error {
        try {
            // Get the offset of the video data from the XMP metadata
            var tag_value = this.metadata.try_get_tag_string ("Xmp.GCamera.MicroVideoOffset");
            if (tag_value != null) {
                int64 reverse_offset = int64.parse (tag_value);
                if (reverse_offset > 0) {
                    var file_size = File.new_for_commandline_arg  (this.filename)
                        .query_info ("standard::size", FileQueryInfoFlags.NONE)
                        .get_size ();
                    return file_size - reverse_offset;
                }
            }
        } catch {
            // If the XMP metadata does not contain the video offset, search for the video tag in the motion photo
            Reporter.warning ("XMPOffsetNotFoundWarning",
                "The XMP metadata does not contain the video offset. Searching for the video tag in the motion photo.");
        }

        const uint8[] VIDEO_TAG = {'f', 't', 'y', 'p'}; // The tag `....ftyp` of MP4 header.
        const int TAG_LENGTH = VIDEO_TAG.length; // The length of the tag.
        int64 offset = -1; // The offset of the video data in the motion photo.
    
        var file = File.new_for_commandline_arg  (this.filename);
        var input_stream = file.read ();

        ssize_t bytes_read; // The number of bytes read from the input stream.
        int64 position = 0; // The current position in the input stream.
        uint8[] buffer = new uint8[Utils.BUFFER_SIZE];
        uint8[] prev_buffer_tail = new uint8[TAG_LENGTH - 1]; // The tail of the previous buffer to avoid boundary crossing.
        uint8[] search_buffer = new uint8[Utils.BUFFER_SIZE + TAG_LENGTH - 1];

        while ((bytes_read = input_stream.read (buffer)) > 0) {
            // Copy the tail of the previous buffer to check for boundary crossing
            Memory.copy (search_buffer, prev_buffer_tail, TAG_LENGTH - 1);
            // Copy the current buffer to the search buffer
            Memory.copy ((void*) ((int64) search_buffer + TAG_LENGTH - 1), buffer, bytes_read); // Vala does not support pointer arithmetic, so we have to cast the pointer to int64 first.
    
            ssize_t buffer_offset = 0;
            for (uint i = 0; i < bytes_read; i += 1) {
                if (buffer[i] == VIDEO_TAG[buffer_offset]) {
                    buffer_offset += 1;
                    if (buffer_offset == TAG_LENGTH) {
                        offset = position - TAG_LENGTH + 1;
                        break;
                    }
                } else {
                    buffer_offset = 0;
                }
                position += 1;
            }

            if (offset != -1) {
                break;
            }
            // Store the tail of the current buffer
            Memory.copy (prev_buffer_tail, (void*) ((int64) buffer + bytes_read - TAG_LENGTH - 1), TAG_LENGTH - 1);
        }

        return offset - 4; // The feature of MP4: there is 4 bytes of size before the tag.
    }
    
    /**
     * Export the main image of the motion photo.
     *
     * The destination path for the exported main image can be specified.
     * If not provided, a default path will be used.
     *
     * @param dest The destination path for the exported main image. If null, a default path will be used.
     * @throws Error if there is an error during the export process.
     * @returns The path of the exported main image.
     */
    public string export_main_image (string? dest = null) throws Error {
        // Export the bytes before `video_offset`
        var file = File.new_for_commandline_arg  (this.filename);
        var input_stream = file.read ();
        string main_image_filename;
        if (dest != null) {
            main_image_filename = dest;
        } else {
            if (this.basename.has_prefix ("MVIMG")) {
                // The main image of a motion photo is named as `IMG_YYYYMMDD_HHMMSS.xxx`
                main_image_filename = Path.build_filename (this.dest_dir, "IMG" + this.basename[5:]);
            } else {
                // If the original image is xxx.yyy, the main image is xxx_0.yyy
                main_image_filename = Path.build_filename (this.dest_dir, this.basename_no_ext + "_0." + this.extension_name);
            }
        }

        var output_stream = File.new_for_commandline_arg  (main_image_filename).replace (null, make_backup, file_create_flags);
        // Write the bytes before `video_offset` to the main image file
        Utils.write_stream_before (input_stream, output_stream, this.video_offset);

        Reporter.info ("Exported main image", main_image_filename);

        if (export_original_metadata) {
            // Copy the metadata from the motion photo to the main image
            try {
                this.metadata.save_file (main_image_filename);
            } catch (Error e) {
                throw new ExportError.MATEDATA_EXPORT_ERROR ("Cannot export the metadata to %s: %s".printf (main_image_filename, e.message));
            }
        }

        return (owned) main_image_filename;
    }

    /**
     * Export the video of the motion photo.
     *
     * The destination path for the exported video can be specified.
     * If not provided, a default path will be used.
     * The video is exported from the motion photo and saved as an MP4 file.
     *
     * @param dest The destination path for the exported video. If not provided, a default path will be used.
     * @throws Error if there is an error during the export process.
     * @returns The path of the exported video file.
     */
    public string export_video (string? dest = null) throws Error {
        /* Export the video of the motion photo. */
        // Export the bytes after `video_offset`
        var file = File.new_for_commandline_arg  (this.filename);
        var input_stream = file.read ();
        string video_filename;
        if (dest != null) {
            video_filename = dest;
        } else {
            if (this.basename.has_prefix ("MVIMG")) {
                // The video of a motion photo is named as `VID_YYYYMMDD_HHMMSS.mp4`
                video_filename = Path.build_filename (this.dest_dir, "VID" + this.basename_no_ext[5:] + ".mp4");
            } else if (this.basename.has_prefix ("IMG")) {
                // If the original image is IMG_YYYYMMDD_HHMMSS.xxx, the video is VID_YYYYMMDD_HHMMSS.mp4
                video_filename = Path.build_filename (this.dest_dir, "VID" + this.basename_no_ext[3:] + ".mp4");
            } else {
                video_filename = Path.build_filename (this.dest_dir, "VID_" + this.basename_no_ext + ".mp4");
            }
        }

        var output_stream = File.new_for_commandline_arg  (video_filename).replace (null, make_backup, file_create_flags);
        // Write the bytes after `video_offset` to the video file
        input_stream.seek (this.video_offset, SeekType.SET);
        Utils.write_stream (input_stream, output_stream);

        Reporter.info ("Exported video file", video_filename);

        return (owned) video_filename;
    }

    public abstract void splites_images_from_video (string? output_format = null, string? dest_dir = null, int threads = 0) throws Error;
}


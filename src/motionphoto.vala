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

public class MotionPhotoConv.MotionPhoto {
    /* MotionPhoto is a class that represents a motion photo. */

    const uint BUFFER_SIZE = 8192;

    string basename;
    string filename;
    GExiv2.Metadata metadata;
    string dest_dir;
    int64 video_offset;
    // string xmp;

    public MotionPhoto (string filename, string? dest_dir = null) throws Error {
        this.metadata = new GExiv2.Metadata ();
        this.metadata.open_path (filename);
        // Get XMP metadata of the image
        // this.xmp = this.metadata.try_get_xmp_packet ();

        this.filename = filename;
        this.basename = Path.get_basename (filename);
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
    }

    inline int64 get_video_offset () throws Error {
        /* Get the offset of the video data in the motion photo. */
        try {
            // Get the offset of the video data from the XMP metadata
            var tag_value = this.metadata.try_get_tag_string ("Xmp.GCamera.MicroVideoOffset");
            if (tag_value != null) {
                int64 reverse_offset = int64.parse (tag_value);
                if (reverse_offset > 0) {
                    var file_size = File.new_for_path (this.filename)
                        .query_info ("standard::size", FileQueryInfoFlags.NONE)
                        .get_size ();
                    return file_size - reverse_offset;
                }
            }
        } catch {
            // If the XMP metadata does not contain the video offset, search for the video tag in the motion photo
            Reporter.warning ("XMPOffsetNotFoundWarning", "The XMP metadata does not contain the video offset. Searching for the video tag in the motion photo. Only support MP4 video.");
        }

        const uint8[] VIDEO_TAG = {'f', 't', 'y', 'p'}; // The tag `....ftyp` of MP4 header.
        const int TAG_LENGTH = VIDEO_TAG.length; // The length of the tag.
        int64 offset = -1; // The offset of the video data in the motion photo.
    
        var file = File.new_for_path (this.filename);
        var input_stream = file.read ();
        var data_input = new DataInputStream (input_stream);
    
        uint8[] buffer = new uint8[BUFFER_SIZE];
        ssize_t bytes_read; // The number of bytes read from the input stream.
        int64 position = 0; // The current position in the input stream.
        uint8[] prev_buffer_tail = new uint8[TAG_LENGTH - 1]; // The tail of the previous buffer to avoid boundary crossing.
    
        while ((bytes_read = data_input.read (buffer)) > 0) {
            uint8[] search_buffer = new uint8[BUFFER_SIZE + TAG_LENGTH - 1];
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
    
    public string export_main_image (string? dest = null) throws Error {
        /* Export the main image of the motion photo. */
        // Export the bytes before `video_offset`
        var file = File.new_for_path (this.filename);
        var input_stream = file.read ();
        var data_input = new DataInputStream (input_stream);
        string main_image_filename;
        if (dest != null) {
            main_image_filename = dest;
        } else {
            if (this.basename.has_prefix ("MVIMG")) {
                // The main image of a motion photo is named as `IMG_YYYYMMDD_HHMMSS.xxx`
                main_image_filename = Path.build_filename (this.dest_dir, "IMG" + this.basename[5:]);
            } else {
                // If the original image is xxx.yyy, the main image is xxx_0.yyy
                var last_dot = this.basename.last_index_of_char ('.');
                if (last_dot == -1) {
                    main_image_filename = Path.build_filename (this.dest_dir, this.basename + "_0");
                } else {
                    main_image_filename = Path.build_filename (this.dest_dir, this.basename[:last_dot] + "_0" + this.basename[last_dot:]);
                }
            }
        }

        var output_stream = File.new_for_path (main_image_filename).replace (null, false, FileCreateFlags.NONE);
        // Write the bytes before `video_offset` to the main image file
        var bytes_to_write = this.video_offset;
        while (bytes_to_write > BUFFER_SIZE) {
            var buffer = new uint8[BUFFER_SIZE];
            data_input.read (buffer);
            output_stream.write (buffer);
            bytes_to_write -= BUFFER_SIZE;
        }
        if (bytes_to_write > 0) {
            var buffer = new uint8[bytes_to_write];
            data_input.read (buffer);
            output_stream.write (buffer);
        }

        metadata.save_file (main_image_filename);
        return (owned) main_image_filename;
    }

    public string export_video (string? dest = null) throws Error {
        /* Export the video of the motion photo. */
        // Export the bytes after `video_offset`
        var file = File.new_for_path (this.filename);
        var input_stream = file.read ();
        var data_input = new DataInputStream (input_stream);
        string video_filename;
        if (dest != null) {
            video_filename = dest;
        } else {
            if (this.basename.has_prefix ("MVIMG")) {
                // The video of a motion photo is named as `VID_YYYYMMDD_HHMMSS.mp4`
                video_filename = Path.build_filename (this.dest_dir, "VID" + this.basename[5:]);
            } else {
                // If the original image is xxx, the video is xxx.mp4
                video_filename = Path.build_filename (this.dest_dir, this.basename + ".mp4");
            }
        }

        var output_stream = File.new_for_path (video_filename).replace (null, false, FileCreateFlags.NONE);
        // Skip the bytes before `video_offset`
        data_input.seek (this.video_offset, GLib.SeekType.SET);
        // Write the bytes after `video_offset` to the video file
        var buffer = new uint8[BUFFER_SIZE];
        ssize_t bytes_read;
        while ((bytes_read = data_input.read (buffer)) > 0) {
            if (bytes_read < BUFFER_SIZE) {
                buffer = buffer[:bytes_read];
            }
            output_stream.write (buffer);
        }

        return (owned) video_filename;
    }

    public void splites_images_from_video_ffmpeg (string video_filename) throws Error {
        /* Export the video of the motion photo and split the video into images. */
        
    }
}

public errordomain MotionPhotoConv.NotMotionPhotosError {
    /* The error domain for the offset not found error. */
    OFFSET_NOT_FOUND_ERROR;
}

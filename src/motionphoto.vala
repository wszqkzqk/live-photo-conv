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

    string basename;
    File file;
    GExiv2.Metadata metadata;
    string dest;
    int64 video_offset;
    string xmp;

    public MotionPhoto (string filename, string? dest = null) throws Error {
        this.metadata = new GExiv2.Metadata ();
        this.metadata.open_path (filename);
        // Get XMP metadata of the image
        this.xmp = this.metadata.try_get_xmp_packet ();
        // Remove the XMP metadata of the main image since it is not a motion photo anymore
        this.metadata.clear_xmp ();

        this.file = File.new_for_path (filename);
        this.basename = Path.get_basename (filename);
        if (dest != null) {
            this.dest = dest;
        } else {
            this.dest = Path.get_dirname (filename);
        }
        this.video_offset = this.get_video_offset ();
    }

    inline int64 get_video_offset () throws Error {
        /* Get the offset of the video data in the motion photo. */
        const uint8[] VIDEO_TAG = {'f', 't', 'y', 'p'}; // The tag `....ftyp` of MP4 header.
        const int TAG_LENGTH = VIDEO_TAG.length; // The length of the tag.
        int64 offset = -1; // The offset of the video data in the motion photo.
    
        var input_stream = this.file.read ();
        var data_input = new DataInputStream (input_stream);
    
        const uint BUFFER_SIZE = 8192;
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
    
    public void export_main_image (string? dest = null) throws Error {
        /* Export the main image of the motion photo. */
        // Export the bytes before `video_offset`
        var input_stream = this.file.read ();
        var data_input = new DataInputStream (input_stream);
        string main_image_filename;
        if (dest != null) {
            main_image_filename = dest;
        } else {
            if (this.basename.has_prefix ("MVIMG")) {
                // The main image of a motion photo is named as `IMG_YYYYMMDD_HHMMSS.jpg`
                main_image_filename = Path.build_filename (this.dest, this.basename.replace ("MVIMG", "IMG"));
            } else {
                // If the original image is xxx.yyy, the main image is xxx_0.yyy
                var last_dot = this.basename.last_index_of_char ('.');
                if (last_dot == -1) {
                    main_image_filename = Path.build_filename (this.dest, this.basename + "_0");
                } else {
                    main_image_filename = Path.build_filename (this.dest, this.basename[:last_dot] + "_0" + this.basename[last_dot:]);
                }
            }
        }

        var output_stream = File.new_for_path (main_image_filename).replace (null, false, FileCreateFlags.NONE, null);
        // Write the bytes before `video_offset` to the main image file
        var bytes_to_write = this.video_offset;
        while (bytes_to_write > 8192) {
            var buffer = new uint8[8192];
            data_input.read (buffer);
            output_stream.write (buffer);
            bytes_to_write -= 8192;
        }
        if (bytes_to_write > 0) {
            var buffer = new uint8[bytes_to_write];
            data_input.read (buffer);
            output_stream.write (buffer);
        }

        metadata.save_file (main_image_filename);
    }

    public void export_video (string? dest = null) throws Error {
        /* Export the video of the motion photo. */
        // Export the bytes after `video_offset`
        var input_stream = this.file.read ();
        var data_input = new DataInputStream (input_stream);
        string video_filename;
        if (dest != null) {
            video_filename = dest;
        } else {
            if (this.basename.has_prefix ("MVIMG")) {
                // The video of a motion photo is named as `VID_YYYYMMDD_HHMMSS.mp4`
                video_filename = Path.build_filename (this.dest, this.basename.replace ("MVIMG", "VID"));
            } else {
                // If the original image is xxx.yyy, the video is xxx_1.yyy
                var last_dot = this.basename.last_index_of_char ('.');
                if (last_dot == -1) {
                    video_filename = Path.build_filename (this.dest, this.basename + "_0.mp4");
                } else {
                    video_filename = Path.build_filename (this.dest, this.basename[:last_dot] + "_0.mp4");
                }
            }
        }

        var output_stream = File.new_for_path (video_filename).replace (null, false, FileCreateFlags.NONE, null);
        // Skip the bytes before `video_offset`
        data_input.seek (this.video_offset, GLib.SeekType.SET);
        // Write the bytes after `video_offset` to the video file
        var buffer = new uint8[8192];
        ssize_t bytes_read;
        while ((bytes_read = data_input.read (buffer)) > 0) {
            if (bytes_read < 8192) {
                buffer = buffer[:bytes_read];
            }
            output_stream.write (buffer);
        }
    }
}

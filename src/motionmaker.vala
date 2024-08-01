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

public class MotionPhotoConv.MotionMaker {
    /* MotionMaker is a class that represents a motion photo maker. */

    const uint BUFFER_SIZE = 8192;

    string main_image_path;
    string video_path;
    string dest;
    GExiv2.Metadata metadata;
    
    public MotionMaker (string main_image_path, string video_path, string? dest = null) throws Error {
        this.main_image_path = main_image_path;
        this.video_path = video_path;

        if (dest != null) {
            this.dest = dest;
        } else {
            var main_basename = Path.get_basename (main_image_path);
            if (main_basename.has_prefix ("IMG")) {
                main_basename = "MVIMG" + main_basename[3:];
                this.dest = Path.build_filename (Path.get_dirname (main_image_path), main_basename);
            } else {
                var video_basename = Path.get_basename (video_path);
                if (video_basename.has_prefix ("VID")) {
                    video_basename = "MVIMG" + video_basename[3:];
                    this.dest = Path.build_filename (Path.get_dirname (main_image_path), video_basename);
                } else {
                    this.dest = Path.build_filename (Path.get_dirname (main_image_path), "MVIMG_" + main_basename);
                }
            }
        }

        this.metadata = new GExiv2.Metadata ();
        this.metadata.open_path (main_image_path);
    }

    public void make_motion_photo () throws Error {
        /* Make a motion photo. */
        var motion_file = File.new_for_path (this.dest);
        var output_stream = motion_file.replace (null, false, FileCreateFlags.NONE);

        var main_file = File.new_for_path (this.main_image_path);
        var main_input_stream = main_file.read ();
        var main_data_input = new DataInputStream (main_input_stream);

        var video_file = File.new_for_path (this.video_path);
        var video_input_stream = video_file.read ();
        var video_data_input = new DataInputStream (video_input_stream);
        var video_size = video_file.query_info ("standard::size", FileQueryInfoFlags.NONE).get_size ();

        uint8[] buffer = new uint8[BUFFER_SIZE];
        ssize_t bytes_read; // The number of bytes read from the input stream.

        while ((bytes_read = main_data_input.read (buffer)) > 0) {
            if (bytes_read < BUFFER_SIZE) {
                buffer = buffer[:bytes_read];
            }
            output_stream.write (buffer);
        }

        while ((bytes_read = video_data_input.read (buffer)) > 0) {
            if (bytes_read < BUFFER_SIZE) {
                buffer = buffer[:bytes_read];
            }
            output_stream.write (buffer);
        }

        output_stream.close ();

        // Copy the metadata from the main image to the motion photo
        // Set the XMP tag `MotionPhoto` to `True`
        this.metadata.try_set_tag_string ("Xmp.GCamera.MicroVideoVersion", "1");
        this.metadata.try_set_tag_string ("Xmp.GCamera.MicroVideo", "1");
        this.metadata.try_set_tag_string ("Xmp.GCamera.MicroVideoOffset", video_size.to_string ());
        this.metadata.save_file (this.dest);
    }
}

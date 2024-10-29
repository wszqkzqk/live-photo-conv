/* livephoto.vala
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
 * @class LivePhotoConv.LiveMaker
 *
 * Represents a live photo maker. This class provides a set of functions
 * to create a live photo by combining a main image and a video file.
 */
public class LivePhotoConv.LiveMaker {

    string main_image_path;
    string video_path;
    string dest;
    GExiv2.Metadata metadata;
    bool make_backup;
    FileCreateFlags file_create_flags;
    
    /**
     * Creates a LiveMaker object. The **main image** and **video file** paths are required.
     * The destination path for the live image file is optional.
     * If not provided, a **default destination** path will be generated based on the main image file.
     * The metadata from the main image can be exported to the live photo. By default, the metadata is exported.
     * The file creation flags can be specified to control the behavior of the file creation process.
     * By default, the destination file will be replaced if it already exists.
     * A backup of the destination file can be created before replacing it.
     *
     * @param main_image_path The path to the main image file.
     * @param video_path The path to the video file.
     * @param dest The destination path for the live image file.
     * If not provided, a default destination path will be generated based on the main image file.
     * @param export_original_metadata Whether to export the metadata from the main image to the live photo.
     * @throws Error if there is an error opening the main image file.
     */
    public LiveMaker (string main_image_path, string video_path,
                        string? dest = null, bool export_original_metadata = true,
                        FileCreateFlags file_create_flags = FileCreateFlags.REPLACE_DESTINATION,
                        bool make_backup = false) throws Error {
        this.main_image_path = main_image_path;
        this.video_path = video_path;
        this.make_backup = make_backup;
        this.file_create_flags = file_create_flags;

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
        if (export_original_metadata) {
            // Copy the metadata from the main image to the live photo
            this.metadata.open_path (main_image_path);
        }
    }

    /**
     * Make a live photo.
     *
     * This function creates a live photo by combining a main image and a video file.
     * The live photo is saved to the specified destination path.
     *
     * @param dest The destination path for the live image file. If not provided, the default destination path will be used.
     * @throws Error if there is an error during the process.
     */
    public void export (string? dest = null) throws Error {
        var live_file = File.new_for_commandline_arg  ((dest == null) ? this.dest : dest);
        var main_file = File.new_for_commandline_arg  (this.main_image_path);
        var video_file = File.new_for_commandline_arg  (this.video_path);

        var video_size = video_file.query_info ("standard::size", FileQueryInfoFlags.NONE).get_size ();

        // Copy the main image to the live photo
        var main_input_stream = main_file.read ();
        var output_stream = live_file.replace (null, false, FileCreateFlags.NONE);
        Utils.write_stream (main_input_stream, output_stream);
        output_stream.close ();

        // Copy the metadata from the main image to the live photo
        // Set the XMP tag `LivePhoto` to `True`
        GExiv2.Metadata.try_register_xmp_namespace ("http://ns.google.com/photos/1.0/camera/", "GCamera");
        this.metadata.try_set_tag_string ("Xmp.GCamera.MicroVideoVersion", "1");
        this.metadata.try_set_tag_string ("Xmp.GCamera.MicroVideo", "1");
        this.metadata.try_set_tag_string ("Xmp.GCamera.MicroVideoOffset", video_size.to_string ());
        try {
            this.metadata.save_file (this.dest);
        }  catch (Error e) {
            throw new ExportError.MATEDATA_EXPORT_ERROR ("Cannot save metadata to `%s': %s", this.dest, e.message);
        }

        // Copy the video to the live photo
        var video_input_stream = video_file.read ();
        var append_stream = live_file.append_to (FileCreateFlags.NONE, null);
        Utils.write_stream (video_input_stream, append_stream);
        append_stream.close ();

        Reporter.info ("Exported live photo", this.dest);
    }
}

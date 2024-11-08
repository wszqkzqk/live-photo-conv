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
 * @class LivePhotoConv.LiveMaker
 *
 * Represents a live photo maker. This class provides a set of functions
 * to create a live photo by combining a main image and a video file.
*/
public abstract class LivePhotoConv.LiveMaker : Object {

    protected GExiv2.Metadata metadata;
    string? main_image_path = null;
    protected string video_path;
    protected string dest;

    public bool make_backup {
        get;
        set;
        default = false;
    }
    public FileCreateFlags file_create_flags {
        get;
        set;
        default = FileCreateFlags.REPLACE_DESTINATION;
    }
    public bool export_original_metadata {
        get;
        set;
        default = true;
    }
    
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
     * @throws Error if there is an error opening the main image file.
    */
    protected LiveMaker (string? main_image_path, string video_path, string? dest = null) {
        this.main_image_path = main_image_path;
        this.video_path = video_path;

        if (dest != null) {
            this.dest = dest;
        } else if (main_image_path != null && main_image_path.has_prefix ("IMG")) {
            var main_basename = Path.get_basename (main_image_path);
            main_basename = "MVIMG" + main_basename[3:];
            this.dest = Path.build_filename (Path.get_dirname (main_image_path), main_basename);
        } else {
            string dest_name;
            var video_basename = Path.get_basename (video_path);
            if (video_basename.has_prefix ("VID")) {
                dest_name = "MVIMG" + video_basename[3:];
            } else {
                dest_name = "MVIMG" + video_basename;
            }

            var last_dot = dest_name.last_index_of_char ('.');
            if (last_dot != -1) {
                dest_name = dest_name[0:last_dot];
            }

            this.dest = Path.build_filename (
                Path.get_dirname (video_path),
                dest_name + ".jpg"
            );
        }

        this.metadata = new GExiv2.Metadata ();
    }

    /**
     * Make a live photo.
     *
     * This function creates a live photo by combining a main image and a video file.
     * The live photo is saved to the specified destination path.
     *
     * @throws Error if there is an error during the process.
    */
    public void export () throws Error {
        int64 video_size = 0;
        if (this.main_image_path != null) {
            video_size = this.export_with_main_image ();
        } else {
            video_size = this.export_with_video_only ();
        }

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
        Reporter.info ("Exported live photo", this.dest);
    }

    inline int64 export_with_main_image () throws Error {
        this.metadata.open_path (main_image_path);
        if (! this._export_original_metadata) {
            // Need to manually clear the metadata if it's not to be exported
            // Because the main image including the metadata is fully copied
            this.metadata.clear ();
        }

        var live_file = File.new_for_commandline_arg  (this.dest);
        var main_file = File.new_for_commandline_arg  (this.main_image_path);
        var video_file = File.new_for_commandline_arg  (this.video_path);

        var video_size = video_file.query_info ("standard::size", FileQueryInfoFlags.NONE).get_size ();

        var output_stream = live_file.replace (null, this._make_backup, this._file_create_flags);
        // Copy the main image to the live photo
        var main_input_stream = main_file.read ();
        Utils.write_stream (main_input_stream, output_stream);
        // Copy the video to the live photo
        var video_input_stream = video_file.read ();
        Utils.write_stream (video_input_stream, output_stream);
        output_stream.close ();

        return video_size;
    }

    protected abstract int64 export_with_video_only () throws Error;
}

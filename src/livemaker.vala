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
 * Live photo maker base class.
 *
 * Provides functionality to create a live photo by combining an optional main image 
 * and a video file. If the main image is null, uses the first video frame.
 */
public abstract class LivePhotoConv.LiveMaker : Object {

    protected GExiv2.Metadata metadata;
    protected string? main_image_path = null;
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
     * Creates a new LiveMaker instance.
     *
     * @param video_path The path to the video file
     * @param main_image_path The path to the main image file (optional)
     * @param dest The destination path for output (optional)
     */
    protected LiveMaker (string video_path, string? main_image_path = null, string? dest = null) {
        this.main_image_path = main_image_path;
        this.video_path = video_path;

        if (dest != null) {
            this.dest = dest;
        } else if (main_image_path != null) {
            string dest_name;
            var main_basename = Path.get_basename (main_image_path);
            if (main_basename.has_prefix ("IMG")) {
                dest_name = "MVIMG" + main_basename[3:];
            } else {
                dest_name = "MVIMG" + main_basename;
            }
            this.dest = Path.build_filename (Path.get_dirname (main_image_path), dest_name);
            // Currently only JPEG is supported as the main image format
            // Google also supports "image/heif" and "image/avif", but GExiv2 does not support them yet
            // So we need to ensure the exported live photo has a JPEG extension
            var lower_dest = this.dest.down();
            if (!(lower_dest.has_suffix (".jpg") || lower_dest.has_suffix (".jpeg"))) {
                this.dest += ".jpg";
            }
        } else {
            string dest_name;
            var video_basename = Path.get_basename (video_path);
            if (video_basename.has_prefix ("VID")) {
                dest_name = "MVIMG" + video_basename[3:];
            } else {
                dest_name = "MVIMG" + video_basename;
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
     * This function creates a live photo by combining an optional main image and a video file.
     * The live photo is saved to the specified destination path.
     * If the main image is `null`, it will use the first frame of the video as the main image.
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

        // Register XMP namespaces
        GExiv2.Metadata.try_register_xmp_namespace ("http://ns.google.com/photos/1.0/camera/", "GCamera");
        GExiv2.Metadata.try_register_xmp_namespace ("http://ns.google.com/photos/1.0/container/", "Container");
        GExiv2.Metadata.try_register_xmp_namespace ("http://ns.google.com/photos/1.0/container/item/", "Item");

        string presentation_timestamp_us_to_write = "-1";
        string? existing_motion_photo_ts = null;
        string? existing_gcamera_ts = null;

        // this.metadata could be populated from main_image_path if export_original_metadata is true
        try {
            existing_motion_photo_ts = this.metadata.try_get_tag_string("Xmp.GCamera.MotionPhotoPresentationTimestampUs");
        } catch (Error e) { /* ignore, tag might not exist or metadata was cleared */ }

        try {
            existing_gcamera_ts = this.metadata.try_get_tag_string("Xmp.GCamera.MicroVideoPresentationTimestampUs");
        } catch (Error e) { /* ignore, tag might not exist or metadata was cleared */ }

        if (existing_motion_photo_ts != null && existing_motion_photo_ts != "") {
            presentation_timestamp_us_to_write = existing_motion_photo_ts;
        } else if (existing_gcamera_ts != null && existing_gcamera_ts != "") {
            presentation_timestamp_us_to_write = existing_gcamera_ts;
        }

        // Set MicroVideo (old standard) tags
        this.metadata.try_set_tag_string ("Xmp.GCamera.MicroVideoVersion", "1");
        this.metadata.try_set_tag_string ("Xmp.GCamera.MicroVideo", "1");
        this.metadata.try_set_tag_string ("Xmp.GCamera.MicroVideoOffset", video_size.to_string ());
        this.metadata.try_set_tag_string ("Xmp.GCamera.MicroVideoPresentationTimestampUs", presentation_timestamp_us_to_write);

        // Set MotionPhoto (new standard) tags
        this.metadata.try_set_tag_string ("Xmp.GCamera.MotionPhoto", "1");
        this.metadata.try_set_tag_string ("Xmp.GCamera.MotionPhotoVersion", "1");
        this.metadata.try_set_tag_string ("Xmp.GCamera.MotionPhotoPresentationTimestampUs", presentation_timestamp_us_to_write);
        // Set Container and Item tags for MotionPhoto
        this.metadata.try_set_xmp_tag_struct ("Xmp.Container.Directory", GExiv2.StructureType.SEQ);
        this.metadata.try_set_tag_string ("Xmp.Container.Directory[1]/Container:Item", "type=Struct");
        this.metadata.try_set_tag_string ("Xmp.Container.Directory[2]/Container:Item", "type=Struct");
        // Item 1: Primary Image (assuming JPEG)
        this.metadata.try_set_tag_string ("Xmp.Container.Directory[1]/Container:Item/Item:Mime", "image/jpeg");
        this.metadata.try_set_tag_string ("Xmp.Container.Directory[1]/Container:Item/Item:Semantic", "Primary");
        // Item:Padding is optional for JPEG, so we omit it or can set to "0"
        // this.metadata.try_set_tag_string ("Xmp.Container.Directory[1]/Container:Item/Item:Padding", "0");
        // Item 2: Video (assuming MP4)
        this.metadata.try_set_tag_string ("Xmp.Container.Directory[2]/Container:Item/Item:Mime", "video/mp4");
        this.metadata.try_set_tag_string ("Xmp.Container.Directory[2]/Container:Item/Item:Semantic", "MotionPhoto");
        this.metadata.try_set_tag_string ("Xmp.Container.Directory[2]/Container:Item/Item:Length", video_size.to_string ());

        try {
            this.metadata.save_file (this.dest);
        }  catch (Error e) {
            throw new ExportError.METADATA_EXPORT_ERROR ("Cannot save metadata to `%s': %s", this.dest, e.message);
        }
        Reporter.info_puts ("Exported live photo", this.dest);
    }

    inline int64 export_with_main_image () throws Error {
        this.metadata.open_path (main_image_path);
        if (! this._export_original_metadata) {
            // Need to manually clear the metadata if it's not to be exported
            // Because the main image including the metadata is fully copied
            this.metadata.clear ();
        }

        // Create the live photo file from the main image and then append the video
        var live_file = this.export_main_image ();
        var video_file = File.new_for_commandline_arg  (this.video_path);

        var video_size = video_file.query_info ("standard::size", FileQueryInfoFlags.NONE).get_size ();

        var output_stream = live_file.append_to (GLib.FileCreateFlags.NONE, null);
        // Copy the video to the live photo
        var video_input_stream = video_file.read ();
        Utils.write_stream (video_input_stream, output_stream);
        output_stream.close ();

        return video_size;
    }

    protected static bool is_supported_main_image (File file) {
        try {
            var file_info = file.query_info ("standard::content-type", FileQueryInfoFlags.NONE);
            var content_type = file_info.get_content_type ();
            // FIXME: Currently only JPEG is supported as the main image format
            // Google also supports "image/heif" and "image/avif", but GExiv2 does not support them yet
            if (content_type == "image/jpeg") {
                return true;
            }
            return false;
        } catch (Error e) {
            Reporter.warning ("FormatWarning", "Cannot query file info for `%s': %s", file.get_path (), e.message);
            return false;
        }
    }

    protected abstract int64 export_with_video_only () throws Error;

    protected abstract File export_main_image () throws Error;
}

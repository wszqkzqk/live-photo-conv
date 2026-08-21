/* Copyright 2024-2026 Zhou Qiankang <wszqkzqk@qq.com>
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
     * Derives the default destination path: MVIMG_<stem>.jpg next to the source.
     *
     * Only JPEG is supported as the main image format for now (Google also
     * supports "image/heif"/"image/avif", but GExiv2 does not), so the
     * exported live photo always gets a JPEG extension.
     *
     * @param source_path The path of the source image or video.
     * @param source_prefix The camera prefix of the source name ("IMG"/"VID").
     */
    static string default_dest (string source_path, string source_prefix) {
        var basename = Path.get_basename (source_path);
        var last_dot = basename.last_index_of_char ('.');
        var stem = last_dot > 0 ? basename[:last_dot] : basename;
        if (stem.has_prefix ("MVIMG"))
            stem = stem[5:];
        else if (stem.has_prefix (source_prefix))
            stem = stem[source_prefix.length:];
        return Path.build_filename (Path.get_dirname (source_path), "MVIMG" + stem + ".jpg");
    }

    /**
     * Creates a new LiveMaker instance.
     *
     * @param video_path The path to the video file
     * @param main_image_path The path to the main image file (optional)
     * @param dest The destination path for output (optional)
     */
    protected LiveMaker (string video_path, string? main_image_path = null, string? dest = null) {
        ensure_exiv2_init ();
        this.main_image_path = main_image_path;
        this.video_path = video_path;

        if (dest != null) {
            this.dest = dest;
        } else if (main_image_path != null) {
            this.dest = default_dest (main_image_path, "IMG");
        } else {
            this.dest = default_dest (video_path, "VID");
        }

        this.metadata = new GExiv2.Metadata ();
    }

    /**
     * Creates a new instance of LiveMaker with the requested backend.
     *
     * The concrete backend class is chosen by the factory; with
     * {@link Backend.AUTO} GStreamer is preferred when built in.
     *
     * @param video_path The path to the video file.
     * @param main_image_path The path to the main image file (optional).
     * @param dest The destination path for output (optional).
     * @param backend The video processing backend to use.
     * @throws Error if the requested backend is unavailable, or the destination is an input file.
     * @return The new LiveMaker instance.
     */
    public static LiveMaker create (string video_path, string? main_image_path = null,
                                    string? dest = null, Backend backend = AUTO) throws Error {
        LiveMaker maker;
#if ENABLE_GST
        if (backend != Backend.FFMPEG)
            maker = new LiveMakerGst (video_path, main_image_path, dest);
        else
#endif
        {
            if (backend == Backend.GST)
                throw new ExportError.GST_ERROR ("GStreamer backend requested but not built in");
            maker = new LiveMakerFFmpeg (video_path, main_image_path, dest);
        }

        // The default dest of an MVIMG-named main image is the image itself
        if (main_image_path != null && Utils.same_file (main_image_path, maker.dest))
            throw new ExportError.FILE_SAVE_ERROR ("`%s' and `%s' are the same file", main_image_path, maker.dest);
        if (Utils.same_file (video_path, maker.dest))
            throw new ExportError.FILE_SAVE_ERROR ("`%s' and `%s' are the same file", video_path, maker.dest);
        return maker;
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

        string presentation_timestamp_us_to_write = "-1";
        string? existing_motion_photo_ts = null;
        string? existing_gcamera_ts = null;

        // this.metadata could be populated from main_image_path if export_original_metadata is true
        try {
            // has_tag guards an empty-valued node, whose get_tag_string returns the next node's value
            if (this.metadata.has_tag ("Xmp.GCamera.MotionPhotoPresentationTimestampUs"))
                existing_motion_photo_ts = this.metadata.get_tag_string("Xmp.GCamera.MotionPhotoPresentationTimestampUs");
        } catch (Error e) { /* ignore, tag might not exist or metadata was cleared */ }

        try {
            if (this.metadata.has_tag ("Xmp.GCamera.MicroVideoPresentationTimestampUs"))
                existing_gcamera_ts = this.metadata.get_tag_string("Xmp.GCamera.MicroVideoPresentationTimestampUs");
        } catch (Error e) { /* ignore, tag might not exist or metadata was cleared */ }

        if (existing_motion_photo_ts != null && int64.try_parse (existing_motion_photo_ts)) {
            presentation_timestamp_us_to_write = existing_motion_photo_ts;
        } else if (existing_gcamera_ts != null && int64.try_parse (existing_gcamera_ts)) {
            presentation_timestamp_us_to_write = existing_gcamera_ts;
        }

        // Clear previous XMP metadata to avoid conflicts
        this.metadata.clear_xmp ();

        // Set MicroVideo (old standard) tags
        this.metadata.set_tag_string ("Xmp.GCamera.MicroVideoVersion", "1");
        this.metadata.set_tag_string ("Xmp.GCamera.MicroVideo", "1");
        this.metadata.set_tag_string ("Xmp.GCamera.MicroVideoOffset", video_size.to_string ());
        this.metadata.set_tag_string ("Xmp.GCamera.MicroVideoPresentationTimestampUs", presentation_timestamp_us_to_write);

        // Set MotionPhoto (new standard) tags
        this.metadata.set_tag_string ("Xmp.GCamera.MotionPhoto", "1");
        this.metadata.set_tag_string ("Xmp.GCamera.MotionPhotoVersion", "1");
        this.metadata.set_tag_string ("Xmp.GCamera.MotionPhotoPresentationTimestampUs", presentation_timestamp_us_to_write);
        // Set Container and Item tags for MotionPhoto
        this.metadata.set_xmp_tag_struct ("Xmp.Container.Directory", GExiv2.StructureType.SEQ);
        this.metadata.set_tag_string ("Xmp.Container.Directory[1]/Container:Item", "type=Struct");
        this.metadata.set_tag_string ("Xmp.Container.Directory[2]/Container:Item", "type=Struct");
        // Item 1: Primary Image (assuming JPEG)
        this.metadata.set_tag_string ("Xmp.Container.Directory[1]/Container:Item/Item:Mime", "image/jpeg");
        this.metadata.set_tag_string ("Xmp.Container.Directory[1]/Container:Item/Item:Semantic", "Primary");
        // Item:Padding is optional for JPEG, so we omit it or can set to "0"
        // this.metadata.set_tag_string ("Xmp.Container.Directory[1]/Container:Item/Item:Padding", "0");
        // Item 2: Video (assuming MP4)
        this.metadata.set_tag_string ("Xmp.Container.Directory[2]/Container:Item/Item:Mime", "video/mp4");
        this.metadata.set_tag_string ("Xmp.Container.Directory[2]/Container:Item/Item:Semantic", "MotionPhoto");
        this.metadata.set_tag_string ("Xmp.Container.Directory[2]/Container:Item/Item:Length", video_size.to_string ());

        try {
            this.metadata.save_file (this.dest);
        }  catch (Error e) {
            throw new ExportError.METADATA_EXPORT_ERROR ("Cannot save metadata to `%s': %s", this.dest, e.message);
        }
        Reporter.info_puts ("Exported live photo", this.dest);
    }

    /**
     * Async version of {@link export}.
     *
     * Runs the synchronous export in a background thread.
     */
    public async void export_async () throws Error {
        SourceFunc callback = export_async.callback;
        Error? export_error = null;
        var thread = new Thread<void> ("live-maker-export", () => {
            try {
                this.export ();
            } catch (Error e) {
                export_error = e;
            }
            Idle.add ((owned) callback);
        });
        yield;
        thread.join ();
        if (export_error != null)
            throw (owned) export_error;
    }

    inline int64 export_with_main_image () throws Error {
        this.metadata.open_path (main_image_path);
        if (!this._export_original_metadata) {
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
            return content_type != null
                && ContentType.get_mime_type (content_type) == "image/jpeg"; // Normalizes platform type strings to MIME
        } catch (Error e) {
            Reporter.warning ("FormatWarning", "Cannot query file info for `%s': %s", file.get_path (), e.message);
            return false;
        }
    }

    /**
     * Export the live photo using only the video file.
     *
     * The first frame of the video is extracted and used as the main image,
     * then the full video is appended to create the live photo.
     *
     * @return The size of the video data appended to the live photo.
     * @throws Error if an error occurs during export.
     */
    protected abstract int64 export_with_video_only () throws Error;

    /**
     * Export the main image to the destination live photo file.
     *
     * Copies or converts the main image to the destination path.
     * If the image format is not supported, it may be converted.
     *
     * @return The file handle of the created live photo.
     * @throws Error if an error occurs during export.
     */
    protected abstract File export_main_image () throws Error;
}

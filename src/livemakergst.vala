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
 * A class for creating live photos using GStreamer.
 */
public class LivePhotoConv.LiveMakerGst : LivePhotoConv.LiveMaker {

    /**
     * Creates a new LiveMakerGst instance.
     *
     * @param video_path Path to the video file
     * @param main_image_path Path to the main image
     * @param dest The destination path for output
     */
    public LiveMakerGst (string video_path, string? main_image_path = null, string? dest = null) {
        base (video_path, main_image_path, dest);
    }

    /**
     * Exports the live photo with video only.
     *
     * @throws IOError If an I/O error occurs during export
     * @throws ExportError If an export error occurs
     * @throws ProcessError If external process execution fails
     * @return The size of the video file
     */
    public override int64 export_with_video_only () throws IOError, ExportError, ProcessError {
        try {
            this.metadata.open_path (this.video_path);
            if (! this.export_original_metadata) {
                this.metadata.clear ();
            }
        } catch (Error e) {
            throw new ExportError.METADATA_EXPORT_ERROR ("Failed to open metadata for video: %s", e.message);
        }

        var live_file = File.new_for_commandline_arg  (this.dest);
        var video_file = File.new_for_commandline_arg  (this.video_path);

        int64 video_size;
        try {
            video_size = video_file.query_info ("standard::size", FileQueryInfoFlags.NONE).get_size ();
        } catch (Error e) {
            throw new IOError.FAILED ("Failed to get video file size: %s".printf (e.message));
        }

        // Enpty args to Gst
        unowned string[] args = null;
        Gst.init (ref args);

        // The input stream of the video file
        FileInputStream video_stream;
        try {
            video_stream = video_file.read ();
        } catch (Error e) {
            throw new IOError.FAILED ("Failed to open video file for reading: %s".printf (e.message));
        }

        // Create a pipeline
        Gst.Bin pipeline;
        try {
            pipeline = Gst.parse_launch ("giostreamsrc name=src ! decodebin ! videoflip method=automatic ! queue ! videoconvert ! video/x-raw,format=RGB,depth=8 ! appsink name=sink") as Gst.Bin;
        } catch (Error e) {
            throw new ExportError.GST_PIPELINE_ERROR ("Failed to create GStreamer pipeline: %s", e.message);
        }

        var giostreamsrc = pipeline.get_by_name ("src");
        giostreamsrc.set_property ("stream", video_stream);
        var appsink = pipeline.get_by_name ("sink") as Gst.App.Sink;

        // Only the first frame is needed
        pipeline.set_state (Gst.State.PLAYING);
        Gst.Sample sample = appsink.pull_sample ();
        pipeline.set_state (Gst.State.NULL);

        var sample2img = new Sample2Img (sample, this.dest, "jpeg");
        FileOutputStream output_stream;
        try {
            output_stream = live_file.replace (null, this.make_backup, this.file_create_flags);
        } catch (Error e) {
            throw new ExportError.FILE_WRITE_ERROR ("Failed to create output live file: %s", e.message);
        }
        sample2img.save_to_stream (output_stream);

        try {
            video_stream.seek (0, GLib.SeekType.SET);
            Utils.write_stream (video_stream, output_stream);
        } catch (Error e) {
            throw new ExportError.FILE_WRITE_ERROR ("Failed to write video to live file: %s", e.message);
        }

        return video_size;
    }

    public override File export_main_image () throws IOError, ExportError {
        var main_file = File.new_for_commandline_arg (this.main_image_path);
        var live_file = File.new_for_commandline_arg (this.dest);

            if (is_supported_main_image (main_file)) {
                // If the main image is supported, copy it to the live photo
                try {
                    this.metadata.open_path (this.main_image_path);
                    if (! this.export_original_metadata) {
                        this.metadata.clear ();
                    }
                } catch (Error e) {
                    throw new ExportError.METADATA_EXPORT_ERROR ("Failed to open metadata for main image: %s", e.message);
                }

                try {
                    var output_stream = live_file.replace (null, this.make_backup, this.file_create_flags);
                    var main_input_stream = main_file.read ();
                    Utils.write_stream (main_input_stream, output_stream);
                } catch (Error e) {
                    throw new ExportError.FILE_WRITE_ERROR ("Failed to copy main image to live file: %s", e.message);
                }
            } else {
                Reporter.warning_puts ("FormatWarning", "Image format is not supported, converting to JPEG");
                // Convert the main image to supported format using Gdk.Pixbuf
                try {
                    var main_file_stream = main_file.read ();
                    var pixbuf = new Gdk.Pixbuf.from_stream (main_file_stream, null);
                    var output_stream = live_file.replace (null, this.make_backup, this.file_create_flags);
                    pixbuf.save_to_stream (output_stream, "jpeg");
                } catch (Error e) {
                    throw new ExportError.FILE_WRITE_ERROR ("Failed to convert main image to JPEG: %s", e.message);
                }
            }

        return live_file;
    }
}

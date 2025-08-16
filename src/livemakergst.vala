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
     * @throws Error If an error occurs during export
     * @return The size of the video file
     */
    public override int64 export_with_video_only () throws Error {
        this.metadata.open_path (this.video_path);
        if (!this.export_original_metadata) {
            this.metadata.clear ();
        }

        // Clear previous XMP metadata to avoid conflicts
        this.metadata.clear_xmp ();

        var live_file = File.new_for_commandline_arg  (this.dest);
        var video_file = File.new_for_commandline_arg  (this.video_path);

        var video_size = video_file.query_info ("standard::size", FileQueryInfoFlags.NONE).get_size ();

        // Enpty args to Gst
        unowned string[] args = null;
        Gst.init (ref args);

        // The input stream of the video file
        var video_stream = video_file.read ();

        // Create a pipeline
        var pipeline = Gst.parse_launch ("giostreamsrc name=src ! decodebin ! videoflip method=automatic ! queue ! videoconvert ! video/x-raw,format=RGB,depth=8 ! appsink name=sink") as Gst.Bin;
        var giostreamsrc = pipeline.get_by_name ("src");
        giostreamsrc.set_property ("stream", video_stream);
        var appsink = pipeline.get_by_name ("sink") as Gst.App.Sink;

        // Only the first frame is needed
        pipeline.set_state (Gst.State.PLAYING);
        Gst.Sample sample = appsink.pull_sample ();
        pipeline.set_state (Gst.State.NULL);

        var sample2img = new Sample2Img (sample, this.dest, "jpeg");
        var output_stream = live_file.replace (null, this.make_backup, this.file_create_flags);
        sample2img.save_to_stream (output_stream);

        video_stream.seek (0, GLib.SeekType.SET);
        Utils.write_stream (video_stream, output_stream);

        return video_size;
    }

    public override File export_main_image () throws Error {
        var main_file = File.new_for_commandline_arg (this.main_image_path);
        var live_file = File.new_for_commandline_arg (this.dest);

        if (is_supported_main_image (main_file)) {
            // If the main image is supported, copy it to the live photo
            this.metadata.open_path (this.main_image_path);
            if (!this.export_original_metadata) {
                this.metadata.clear ();
            }

            var output_stream = live_file.replace (null, this.make_backup, this.file_create_flags);
            var main_input_stream = main_file.read ();
            Utils.write_stream (main_input_stream, output_stream);
        } else {
            // Convert the main image to supported format
            Reporter.warning_puts ("FormatWarning", "Image format is not supported, converting to JPEG");
            var main_file_stream = main_file.read ();
            var pixbuf = new Gdk.Pixbuf.from_stream (main_file_stream, null);
            var output_stream = live_file.replace (null, this.make_backup, this.file_create_flags);
            pixbuf.save_to_stream (output_stream, "jpeg");
        }

        return live_file;
    }
}

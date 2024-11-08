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
 * @class LiveMakerGst
 * @brief A class for creating live photos using GStreamer.
 */
public class LivePhotoConv.LiveMakerGst : LivePhotoConv.LiveMaker {

    /**
     * @brief Constructs a new LiveMakerGst instance.
     * @param main_image_path The path to the main image.
     * @param video_path The path to the video file.
     * @param dest The destination path for the output.
     */
    public LiveMakerGst (string? main_image_path, string video_path, string? dest = null) {
        base (main_image_path, video_path, dest);
    }

    /**
     * @brief Exports the live photo with video only.
     * @return The size of the video file.
     * @throws Error if an error occurs during export.
     */
    public override int64 export_with_video_only () throws Error {
        this.metadata.open_path (this.video_path);
        if (! this.export_original_metadata) {
            this.metadata.clear ();
        }

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
}

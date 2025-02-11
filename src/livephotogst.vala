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
 * Implementation of LivePhoto using GStreamer for video processing.
 */
public class LivePhotoConv.LivePhotoGst : LivePhotoConv.LivePhoto {
    /**
     * Creates a new instance.
     *
     * @param filename The path to the live photo file
     * @param dest_dir The destination directory for the converted live photo
     * @throws Error If an error occurs while retrieving the offset
     */
    public LivePhotoGst (string filename, string? dest_dir = null) throws Error {
        base (filename, dest_dir);
    }

    /**
     * Split the video into images.
     *
     * @param output_format The format of the output images
     * @param dest_dir The destination directory for output
     * @param jobs Number of concurrent jobs for processing
     * @throws Error If an error occurs during processing
     */
    public override void splites_images_from_video (string? output_format = null, string? dest_dir = null, int jobs = 0) throws Error {
        // Enpty args to Gst
        unowned string[] args = null;
        Gst.init (ref args);

        // Create a pipeline
        var pipeline = Gst.parse_launch ("appsrc name=src ! decodebin ! videoflip method=automatic ! queue ! videoconvert ! video/x-raw,format=RGB,depth=8 ! appsink name=sink") as Gst.Bin;
        var appsrc = pipeline.get_by_name ("src") as Gst.App.Src;
        var appsink = pipeline.get_by_name ("sink") as Gst.App.Sink;

        // NOTE: `giostreamsrc` does not support `seek` and will read from the beginning of the file,
        // so use `appsrc` instead.
        // Create a new thread to push data
        Thread<ExportError?> push_thread = new Thread<ExportError?> ("file_pusher", () => {
            try {
                // Set the video source
                var file = File.new_for_commandline_arg (this.filename);
                var input_stream = file.read ();
                input_stream.seek (this.video_offset, SeekType.SET);

                // Push the data to appsrc
                uint8[] buffer = new uint8[Utils.BUFFER_SIZE];
                ssize_t size;
                while ((size = input_stream.read (buffer)) > 0) {
                    buffer.length = (int) size;
                    var gst_buffer = new Gst.Buffer.wrapped (buffer);
                    var flow_ret = appsrc.push_buffer (gst_buffer);
                    if (flow_ret != Gst.FlowReturn.OK) {
                        appsrc.end_of_stream ();
                        return new ExportError.FILE_PUSH_ERROR ("Pushing to appsrc failed, flow returned %s", flow_ret.to_string ());
                    }
                    buffer.length = Utils.BUFFER_SIZE;
                }

                // Send EOS to appsrc before returning
                appsrc.end_of_stream ();
                return null;
            } catch (Error e) {
                appsrc.end_of_stream ();
                return new ExportError.FILE_PUSH_ERROR ("Pushing to appsrc failed: %s", e.message);
            }
        });
        pipeline.set_state (Gst.State.PLAYING);

        // Create a threadpool to process the images
        if (jobs == 0) {
            jobs = (int) get_num_processors ();
        }
        var pool = new ThreadPool<Sample2Img>.with_owned_data ((item) => {
            try {
                if (export_original_metadata) {
                    item.export (this.metadata);
                } else {
                    item.export ();
                }
            } catch (Error e) {
                Reporter.error_puts ("Error", e.message);
            }
        }, jobs, false);

        Gst.Sample sample;
        uint index = 1;
        string filename_no_index_ext = Path.build_filename (
            (dest_dir == null) ? this.dest_dir : dest_dir,
            ((this.basename.has_prefix ("MVIMG")) ?
                "IMG" + this.basename_no_ext[5:] :
                this.basename_no_ext)
        );
        unowned var extension = (output_format != null) ? output_format : this.extension_name;
        // for jpg, pixbuf requires the format to be "jpeg"
        unowned var format = (extension == "jpg") ? "jpeg" : extension;
        while ((sample = appsink.pull_sample ()) != null) {
            string filename = filename_no_index_ext + "_%u.".printf (index) + extension;
            var item = new Sample2Img (sample, filename, format);
            pool.add ((owned) item);
            index += 1;
        }

        var push_file_error = push_thread.join ();
        if (push_file_error != null) {
            throw push_file_error;
        }
        ThreadPool.free ((owned) pool, false, true);
        pipeline.set_state (Gst.State.NULL);
    }
}

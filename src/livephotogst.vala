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

/** Watches a pipeline's bus for errors and warnings. */
internal class LivePhotoConv.PipelineWatch : Object {
    /** The first bus error received, if any. */
    public Error? error = null;

    /**
     * Starts watching the pipeline's bus.
     *
     * Errors and warnings are forwarded to stderr; the first error is
     * recorded in {@link error} and the pipeline is asynchronously forced
     * to NULL so that blocking pull_sample () calls wake up instead of
     * hanging.
     *
     * @param pipeline The pipeline to watch.
     */
    internal PipelineWatch (Gst.Bin pipeline) {
        pipeline.get_bus ().set_sync_handler ((bus, message) => {
            Error err;
            string debug;
            if (message.type == Gst.MessageType.ERROR) {
                message.parse_error (out err, out debug);
                Reporter.error_puts ("GstError", "%s (%s)".printf (err.message, debug));
                fail (err, message.src);
            } else if (message.type == Gst.MessageType.WARNING) {
                message.parse_warning (out err, out debug);
                Reporter.warning_puts ("GstWarning", "%s (%s)".printf (err.message, debug));
            }
            return Gst.BusSyncReply.PASS;
        });

        // No linked decodebin src pad means no consumable stream, which does not reliably error; fail to unblock pull_sample ()
        var dec = pipeline.get_by_name ("dec");
        if (dec != null) {
            dec.no_more_pads.connect ((d) => {
                bool any_linked = false;
                foreach (unowned var pad in d.srcpads) {
                    if (pad.is_linked ()) {
                        any_linked = true;
                        break;
                    }
                }
                if (!any_linked) {
                    fail (new ExportError.NO_VIDEO_STREAM_ERROR ("No video stream in the input"), d);
                }
            });
        }
    }

    /**
     * Records the first failure and asynchronously forces the pipeline to
     * NULL, waking any blocking pull_sample ().
     *
     * @param err The error to record
     * @param src An object in the pipeline, used to locate the top-level element
     */
    void fail (Error err, Gst.Object? src) {
        if (this.error == null)
            this.error = err;
        var top = src;
        while (top != null && top.parent != null)
            top = top.parent;
        (top as Gst.Element)?.call_async ((element) => {
            element.set_state (Gst.State.NULL);
        });
    }
}

/**
 * Implementation of LivePhoto using GStreamer for video processing.
 */
internal class LivePhotoConv.LivePhotoGst : LivePhotoConv.LivePhoto {
    const string GST_PIPELINE = "appsrc name=src ! decodebin name=dec ! videoflip method=automatic ! queue ! videoconvert ! video/x-raw,format=RGB,depth=8 ! appsink name=sink";

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

    public override void split_images_from_video (string? output_format = null, string? dest_dir = null, int threads = 0) throws Error {
        // Enpty args to Gst
        unowned string[] args = null;
        Gst.init (ref args);

        // Create a pipeline
        var pipeline = Gst.parse_launch (GST_PIPELINE) as Gst.Bin;
        var watch = new PipelineWatch (pipeline);
        var appsrc = pipeline.get_by_name ("src") as Gst.App.Src;
        var appsink = pipeline.get_by_name ("sink") as Gst.App.Sink;
        appsink.max_buffers = 2;
        // Back-pressure when the pipeline is busy, so compressed data cannot pile up either
        appsrc.max_bytes = 8 << 20;
        appsrc.block = true;

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
        if (threads <= 0) {
            threads = (int) get_num_processors ();
        }
        int export_errors = 0;
        var export_meta = export_original_metadata ? this.metadata_for_export () : null;
        // Bound the in-flight frame backlog with token slots
        var slots = new AsyncQueue<ulong> ();
        for (int i = 0; i < 2 * threads; i += 1) {
            slots.push (1); // g_async_queue_push rejects null data, need to be non-zero
        }
        var pool = new ThreadPool<Sample2Img>.with_owned_data ((item) => {
            try {
                item.export (export_meta);
            } catch (Error e) {
                AtomicInt.inc (ref export_errors);
                Reporter.error_puts ("Error", e.message);
            }
            slots.push (1);
        }, threads, false);

        Gst.Sample sample;
        uint index = 1;
        string filename_no_index_ext = Path.build_filename (
            (dest_dir == null) ? this.dest_dir : dest_dir,
            ((this.basename.has_prefix ("MVIMG")) ?
                "IMG" + this.basename_no_ext[5:] :
                this.basename_no_ext)
        );
        var extension = (output_format ?? this.extension_name).down ();
        // for jpg, pixbuf requires the format to be "jpeg"
        var format = (extension == "jpg") ? "jpeg" : extension;
        while ((sample = appsink.pull_sample ()) != null) {
            string filename = filename_no_index_ext + "_%u.".printf (index) + extension;
            try {
                var item = new Sample2Img (sample, filename, format);
                slots.pop ();
                pool.add ((owned) item);
            } catch (Error e) {
                AtomicInt.inc (ref export_errors);
                Reporter.error_puts ("Error", e.message);
            }
            index += 1;
        }

        var push_file_error = push_thread.join ();
        pipeline.set_state (Gst.State.NULL);
        ThreadPool.free ((owned) pool, false, true);
        if (watch.error != null) {
            throw watch.error;
        }
        if (push_file_error != null) {
            throw push_file_error;
        }
        if (export_errors > 0) {
            throw new ExportError.GST_ERROR ("Failed to export %d frame(s)", export_errors);
        }
    }

    public override void generate_long_exposure (string dest_path) throws Error {
        if (Utils.same_file (this.filename, dest_path))
            throw new ExportError.FILE_SAVE_ERROR ("`%s' and `%s' are the same file", this.filename, dest_path);

        unowned string[] args = null;
        Gst.init (ref args);

        var pipeline = Gst.parse_launch (GST_PIPELINE) as Gst.Bin;
        var watch = new PipelineWatch (pipeline);
        var appsrc = pipeline.get_by_name ("src") as Gst.App.Src;
        var appsink = pipeline.get_by_name ("sink") as Gst.App.Sink;

        Thread<ExportError?> push_thread = new Thread<ExportError?> ("file_pusher", () => {
            try {
                var file = File.new_for_commandline_arg (this.filename);
                var input_stream = file.read ();
                input_stream.seek (this.video_offset, SeekType.SET);

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
                appsrc.end_of_stream ();
                return null;
            } catch (Error e) {
                appsrc.end_of_stream ();
                return new ExportError.FILE_PUSH_ERROR ("Pushing to appsrc failed: %s", e.message);
            }
        });
     
        pipeline.set_state (Gst.State.PLAYING);

        uint64[]? accumulator = null;
        int width = 0, height = 0;
        uint64 frames = 0;

        while (true) {
            var sample = appsink.pull_sample ();
            if (sample == null) {
                break;
            }

            if (accumulator == null) {
                unowned var caps = sample.get_caps ();
                unowned var info = caps.get_structure (0);
                info.get_int ("width", out width);
                info.get_int ("height", out height);
                accumulator = new uint64[width * height * 3];
            }

            Gst.MapInfo map;
            var buf = sample.get_buffer ();
            if (buf.map (out map, Gst.MapFlags.READ)) {
                unowned uint8[] data = map.data;
                int len = data.length;
                if (len > accumulator.length) {
                    len = accumulator.length;
                }

                for (int i = 0; i < len ; i += 1) {
                    accumulator[i] += data[i];
                }
                buf.unmap (map);
                frames += 1;
            }
        }

        pipeline.set_state (Gst.State.NULL);
        var push_error = push_thread.join ();
        if (watch.error != null) {
            throw watch.error;
        }
        if (push_error != null) {
            throw push_error;
        }
        if (frames == 0 || accumulator == null) {
            throw new ExportError.GST_ERROR ("No frames decoded");
        }

        uint8[] pixel_data = new uint8[width * height * 3];
        for (uint64 i = 0; i < accumulator.length; i += 1) {
            pixel_data[i] = (uint8) ((accumulator[i] + frames / 2) / frames);
        }

        var pixbuf = new Gdk.Pixbuf.from_data (
            (owned) pixel_data,
            Gdk.Colorspace.RGB,
            false,
            8,
            width,
            height,
            width * 3
        );
        pixbuf = pixbuf_with_opaque_alpha (pixbuf);

        string format;
        var last_dot = dest_path.last_index_of_char ('.');
        if (last_dot == -1 || last_dot + 1 >= dest_path.length) {
            format = this.extension_name.down ();
        } else {
            format = dest_path[(last_dot + 1):].down ();
        }
        if (format == "jpg") {
            format = "jpeg";
        }
        pixbuf.save (dest_path, format);
        if (export_original_metadata) {
            try {
                this.metadata_for_export ().save_file (dest_path);
            } catch (Error e) {
                Reporter.error_puts ("Error", e.message);
            }
        }

        Reporter.info_puts ("Exported long exposure image", dest_path);
    }
}

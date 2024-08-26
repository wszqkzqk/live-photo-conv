/* motionphotogst.vala
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

public class MotionPhotoConv.MotionPhotoGst : MotionPhotoConv.MotionPhoto {
    /**
     * Creates a new instance of the MotionPhotoGst class.
     *
     * The path to the **motion photo** file is required.
     * The destination directory for the converted motion photo is optional.
     * If not provided, the directory of the input file will be used.
     * The file creation flags can be specified to control the behavior of the file creation process.
     * By default, the destination file will be replaced if it already exists.
     * A backup of the destination file can be created before replacing it.
     * The original metadata of the motion photo can be exported.
     *
     * @param filename The path to the motion photo file.
     * @param dest_dir The destination directory for the converted motion photo. If not provided, the directory of the input file will be used.
     * @param export_metadata Whether to export the original metadata of the motion photo. Default is true.
     * @throws Error if an error occurs while retrieving the offset.
     */
    public MotionPhotoGst (string filename, string? dest_dir = null, bool export_metadata = true,
                           FileCreateFlags file_create_flags = FileCreateFlags.REPLACE_DESTINATION, bool make_backup = false) throws Error {
        base (filename, dest_dir, export_metadata, file_create_flags, make_backup);
    }

    /**
     * Split the video into images.
     *
     * The video of the motion photo is split into images.
     * The images are saved to the destination directory with the specified output format.
     * If the output format is not provided, the default extension name will be used.
     * The name of the images is generated based on the basename of the motion photo.
     *
     * @param output_format The format of the output images. If not provided, the default extension name will be used.
     * @param video_source The path to the video source. If not provided or the file does not exist, the video will be exported from the motion photo.
     * @param dest_dir The destination directory where the images will be saved. If not provided, the default destination directory will be used.
     *
     * @throws Error If FFmpeg exits with an error.
     */
    public override void splites_images_from_video (string? output_format = null, string? dest_dir = null, int threads = 0) throws Error {
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
            } catch (Error e) {
                appsrc.end_of_stream ();
                return new ExportError.FILE_PUSH_ERROR ("Pushing to appsrc failed: %s", e.message);
            }
            appsrc.end_of_stream ();
            return null;
        });
        pipeline.set_state (Gst.State.PLAYING);

        // Create a threadpool to process the images
        if (threads == 0) {
            threads = (int) get_num_processors ();
        }
        var pool = new ThreadPool<Sample2Img>.with_owned_data ((item) => {
            try {
                if (export_original_metadata) {
                    item.export (this.metadata);
                } else {
                    item.export ();
                }
            } catch (Error e) {
                Reporter.error ("Error", e.message);
            }
        }, threads, false);

        Gst.Sample sample;
        uint index = 1;
        string filename_no_index_ext = Path.build_filename (
            dest_dir,
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

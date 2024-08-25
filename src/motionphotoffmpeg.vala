/* motionphotoffmpeg.vala
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
 * @class MotionPhotoConv.MotionPhotoFFmpeg
 *
 * Represents a class that extends the MotionPhoto class and provides functionality for working with motion photos using FFmpeg.
 */
public class MotionPhotoConv.MotionPhotoFFmpeg : MotionPhotoConv.MotionPhoto {

    /**
     * Creates a new instance of the MotionPhotoFFmpeg class.
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
    public MotionPhotoFFmpeg (string filename, string? dest_dir = null, bool export_metadata = true,
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
     public override void splites_images_from_video (string? output_format = null, string? dest_dir = null, int threads = 1) throws Error {
        /* Export the video of the motion photo and split the video into images. */
        string name_to_printf;
        string dest;

        var format = (output_format != null) ? output_format : this.extension_name;

        if (threads != 1) {
            Reporter.warning ("NotImplementedWarning", "The `threads` parameter of FFmpeg mode is not implemented.");
        }

        if (this.basename.has_prefix ("MVIMG")) {
            name_to_printf = "IMG" + this.basename_no_ext[5:] + "_%d." + format;
        } else {
            name_to_printf = this.basename_no_ext + "_%d." + format;
        }

        if (dest_dir != null) {
            dest = Path.build_filename (dest_dir, name_to_printf);
        } else {
            dest = Path.build_filename (this.dest_dir, name_to_printf);
        }

        string[] commands;
        if (format.ascii_down () == "webp") {
            // Spcify the `libwebp` encoder to avoid the `libwebp_anim` encoder in `ffmpeg`
            commands = {"ffmpeg", "-progress", "-", // Split progress to stdout
                        "-loglevel", "fatal",
                        "-hwaccel", "auto",
                        "-i", "pipe:0",
                        "-f", "image2",
                        "-c:v", "libwebp",
                        "-y", dest};
        } else {
            commands = {"ffmpeg", "-progress", "-",
                        "-loglevel", "fatal",
                        "-hwaccel", "auto",
                        "-i", "pipe:0",
                        "-f", "image2",
                        "-y", dest};
        }

        var subprcs = new Subprocess.newv (commands,
            SubprocessFlags.STDOUT_PIPE |
            SubprocessFlags.STDERR_PIPE |
            SubprocessFlags.STDIN_PIPE);

        var pipe_stdin = subprcs.get_stdin_pipe ();
        var pipe_stdout = subprcs.get_stdout_pipe ();
        var pipe_stderr = subprcs.get_stderr_pipe ();

        var file = File.new_for_commandline_arg (this.filename);
        var input_stream = file.read ();
        input_stream.seek (this.video_offset, SeekType.SET);
        Utils.write_stream (input_stream, pipe_stdin);

        pipe_stdin.close (); // Close the pipe to signal the end of the input stream, MUST before `wait`
        subprcs.wait ();

        var exit_code = subprcs.get_exit_status ();

        if (exit_code != 0) {
            var subprcs_error = Utils.get_string_from_file_input_stream (pipe_stderr);
            throw new ExportError.FFMPEG_EXIED_WITH_ERROR (
                "Command `%s' failed with %d - `%s'",
                string.joinv (" ", commands),
                exit_code,
                subprcs_error);
        }

        if (export_original_metadata) {
            MatchInfo match_info;

            var subprcs_output = Utils.get_string_from_file_input_stream (pipe_stdout);
            var re_frame = /.*frame=\s*(\d+)/s;

            re_frame.match (subprcs_output, 0, out match_info);
            if (match_info.matches ()) {
                // Set the metadata of the images
                var num_frames = int64.parse (match_info.fetch (1));
                for (int i = 1; i < num_frames + 1; i += 1) {
                    var image_filename = Path.build_filename (this.dest_dir, name_to_printf.printf (i));
                    try {
                        metadata.save_file (image_filename);
                    } catch (Error e) {
                        throw new ExportError.MATEDATA_EXPORT_ERROR ("Cannot save metadata to `%s': %s", image_filename, e.message);
                    }
                }
            } else {
                Reporter.warning ("FFmpegOutputParseWarning", "Failed to parse the output of FFmpeg.");
            }
        }
    }
}

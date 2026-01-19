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
 * Implementation of LivePhoto using FFmpeg.
*/
public class LivePhotoConv.LivePhotoFFmpeg : LivePhotoConv.LivePhoto {

    /**
     * Creates a new instance of the LivePhotoFFmpeg class.
     *
     * The path to the **live photo** file is required.
     * The destination directory for the converted live photo is optional.
     * If not provided, the directory of the input file will be used.
     * The file creation flags can be specified to control the behavior of the file creation process.
     * By default, the destination file will be replaced if it already exists.
     * A backup of the destination file can be created before replacing it.
     * The original metadata of the live photo can be exported.
     *
     * @param filename The path to the live photo file.
     * @param dest_dir The destination directory for the converted live photo. If not provided, the directory of the input file will be used.
     * @throws Error if an error occurs while retrieving the offset.
    */
    public LivePhotoFFmpeg (string filename, string? dest_dir = null) throws Error {
        base (filename, dest_dir);
    }

    /**
     * Split the video into images.
     *
     * The video of the live photo is split into images.
     * The images are saved to the destination directory with the specified output format.
     * If the output format is not provided, the default extension name will be used.
     * The name of the images is generated based on the basename of the live photo.
     *
     * @param output_format The format of the output images. If not provided, the default extension name will be used.
     * @param dest_dir The destination directory where the images will be saved. If not provided, the default destination directory will be used.
     * @param threads The number of threads to run in parallel. (Ignored in this implementation)
     *
     * @throws Error If FFmpeg exits with an error.
    */
     public override void split_images_from_video (string? output_format = null, string? dest_dir = null, int threads = 1) throws Error {
        /* Export the video of the live photo and split the video into images. */
        string name_to_printf;
        string dest;

        var format = (output_format != null) ? output_format : this.extension_name;

        if (threads != 0 && threads != 1) {
            Reporter.warning_puts ("NotImplementedWarning", "The `threads` parameter of FFmpeg mode is not implemented.");
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
            commands = {
                "ffmpeg", "-progress", "-", // Split progress to stdout
                "-loglevel", "error",
                "-hwaccel", "auto",
                "-i", "pipe:0",
                "-f", "image2",
                "-c:v", "libwebp",
                "-y", dest, null
            };
        } else {
            commands = {
                "ffmpeg", "-progress", "-",
                "-loglevel", "error",
                "-hwaccel", "auto",
                "-i", "pipe:0",
                "-f", "image2",
                "-y", dest, null
            };
        }

        var subprcs = new Subprocess.newv (commands,
            SubprocessFlags.STDOUT_PIPE |
            SubprocessFlags.STDERR_PIPE |
            SubprocessFlags.STDIN_PIPE);

        Thread<ExportError?> push_thread = push_video_to_subprcs (subprcs);

        var pipe_stdout = subprcs.get_stdout_pipe ();
        var pipe_stderr = subprcs.get_stderr_pipe ();

        var pipe_stdout_dis = new DataInputStream (pipe_stdout);
        var re_frame = /^frame=\s*(\d+)/;
        MatchInfo match_info;

        string line;
        int64 frame_processed = 0;
        while ((line = pipe_stdout_dis.read_line ()) != null) {
            if (re_frame.match (line, 0, out match_info)) {
                var frame = int64.parse (match_info.fetch (1));
                for (; frame_processed < frame; frame_processed += 1) {
                    var image_filename = Path.build_filename (
                        (dest_dir == null) ? this.dest_dir : dest_dir,
                        name_to_printf.printf (frame_processed + 1)
                    );
                    Reporter.info_puts ("Exported image", image_filename);

                    if (export_original_metadata) {
                        try {
                            metadata.save_file (image_filename);
                        } catch (Error e) {
                            // DO NOT throw the error, just report it
                            // because the image exporting is not affected
                            Reporter.error_puts ("Error", e.message);
                        }
                    }
                }
            }
        }

        var push_file_error = push_thread.join ();
        // Report the error of data pushing,
        // report here instead of throwing it to avoid zombie subprocess
        if (push_file_error != null) {
            Reporter.error_puts ("FilePushError", push_file_error.message);
        }
        subprcs.wait ();

        var exit_code = subprcs.get_exit_status ();

        if (exit_code != 0) {
            string? subprcs_error = null;
            try { // Try to get the error message from stderr
                subprcs_error = Utils.get_string_from_file_input_stream (pipe_stderr);
            } catch {} // If failed, throw the error without the error message

            if (subprcs_error == null) {
                throw new ExportError.FFMPEG_EXIED_WITH_ERROR (
                    "Command `%s' failed with %d",
                    string.joinv (" ", commands),
                    exit_code);
            }
            throw new ExportError.FFMPEG_EXIED_WITH_ERROR (
                "Command `%s' failed with %d - `%s'",
                string.joinv (" ", commands),
                exit_code,
                subprcs_error);
        }
    }

    public override void generate_long_exposure (string dest_path) throws Error {
        var frame_count = get_frame_count ();

        string[] commands;
        if (dest_path.down ().has_suffix (".webp")) {
            commands = {
                "ffmpeg", "-progress", "-",
                "-loglevel", "error",
                "-hwaccel", "auto",
                "-i", "pipe:0",
                "-vf", "tmix=frames=" + frame_count.to_string (),
                "-f", "image2",
                "-c:v", "libwebp",
                "-update", "1",
                "-y", dest_path, null
            };
        } else {
            commands = {
                "ffmpeg", "-progress", "-",
                "-loglevel", "error",
                "-hwaccel", "auto",
                "-i", "pipe:0",
                "-vf", "tmix=frames=" + frame_count.to_string (),
                "-f", "image2",
                "-update", "1",
                "-y", dest_path, null
            };
        }

        var subprcs = new Subprocess.newv (commands,
            SubprocessFlags.STDOUT_PIPE |
            SubprocessFlags.STDERR_PIPE |
            SubprocessFlags.STDIN_PIPE);

        var push_thread = push_video_to_subprcs (subprcs);
        subprcs.wait ();

        var push_file_error = push_thread.join ();
        if (push_file_error != null) {
            Reporter.error_puts ("FilePushError", push_file_error.message);
        }

        var exit_code = subprcs.get_exit_status ();

        if (exit_code != 0) {
            string? subprcs_error = null;
            try { 
                var pipe_stderr = subprcs.get_stderr_pipe ();
                subprcs_error = Utils.get_string_from_file_input_stream (pipe_stderr);
            } catch {}

            throw new ExportError.FFMPEG_EXIED_WITH_ERROR (
                "Command `%s' failed with %d - `%s'",
                string.joinv (" ", commands),
                exit_code,
                subprcs_error ?? "Unknown error");
        }
        
        if (export_original_metadata) {
            try {
                metadata.save_file (dest_path);
            } catch (Error e) {
                Reporter.error_puts ("Error", e.message);
            }
        }

        Reporter.info_puts ("Exported long exposure image", dest_path);
    }

    uint64 get_frame_count () throws Error {
        string[] commands = {
            "ffprobe", 
            "-v", "error", 
            "-select_streams", "v:0", 
            "-count_packets", 
            "-show_entries", "stream=nb_read_packets", 
            "-of", "csv=p=0", 
            "pipe:0", null
        };

        var subprcs = new Subprocess.newv (commands,
            SubprocessFlags.STDOUT_PIPE |
            SubprocessFlags.STDIN_PIPE);

        var push_thread = push_video_to_subprcs (subprcs);

        string output = "";
        try {
            var pipe_stdout = subprcs.get_stdout_pipe ();
            output = Utils.get_string_from_file_input_stream (pipe_stdout);
        } catch {}

        subprcs.wait ();
        var push_error = push_thread.join ();
        if (push_error != null) {
            throw push_error;
        } else if (subprcs.get_exit_status () != 0) {
            throw new ExportError.FFMPEG_EXIED_WITH_ERROR ("ffprobe failed to count frames");
        }

        return uint64.parse (output.strip ());
    }

    Thread<ExportError?> push_video_to_subprcs (Subprocess subprcs) {
        return new Thread<ExportError?> ("file_pusher-%s".printf (subprcs.get_identifier ()), () => {
            try {
                var pipe_stdin = subprcs.get_stdin_pipe ();
                var file = File.new_for_commandline_arg (this.filename);
                var input_stream = file.read ();
                input_stream.seek (this.video_offset, SeekType.SET);
                Utils.write_stream (input_stream, pipe_stdin);

                // `subprcs.get_stdin_pipe ()`'s return value is **unowned**,
                // so we need to close it **manually**.
                // Close the pipe to signal the end of the input stream,
                // otherwise the process will be **blocked**.
                pipe_stdin.close ();
                return null;
            } catch (Error e) {
                return new ExportError.FILE_PUSH_ERROR ("Pushing to subprocess failed: %s", e.message);
            }
        });
    }
}

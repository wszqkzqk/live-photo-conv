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
 * Implementation of LiveMaker using FFmpeg.
 */
public class LivePhotoConv.LiveMakerFFmpeg : LivePhotoConv.LiveMaker {
    const string[] FFMPEG_COMMANDS = {
        "ffmpeg",
        "-loglevel", "fatal",
        "-hwaccel", "auto",
        "-i", "pipe:0",
        "-vf", "select=eq(n\\,0)",
        "-f", "image2pipe",
        "-vcodec", "mjpeg",
        "pipe:1", null, // Need to be null-terminated
    };

    /**
     * Creates a new instance.
     *
     * @param video_path Path to the video file
     * @param main_image_path Path to the main image
     * @param dest Destination path for output
     */
    public LiveMakerFFmpeg (string video_path, string? main_image_path = null, string? dest = null) {
        base (video_path, main_image_path, dest);
    }

    /**
     * Exports live photo using video only.
     *
     * @return The size of the video file
     * @throws Error If an error occurs during export
     */
    public override int64 export_with_video_only () throws Error {
        this.metadata.open_path (this.video_path);
        if (! this.export_original_metadata) {
            this.metadata.clear ();
        }

        var live_file = File.new_for_commandline_arg  (this.dest);
        var video_file = File.new_for_commandline_arg  (this.video_path);

        var video_size = video_file.query_info ("standard::size", FileQueryInfoFlags.NONE).get_size ();

        // Create a subprocess to run FFmpeg
        var subprcs = new Subprocess.newv (FFMPEG_COMMANDS,
            SubprocessFlags.STDOUT_PIPE |
            SubprocessFlags.STDERR_PIPE |
            SubprocessFlags.STDIN_PIPE);
        
        // Set the video source
        var pipe_stdin = subprcs.get_stdin_pipe ();
        var video_stream = video_file.read ();
        Utils.write_stream (video_stream, pipe_stdin);
        // Close the pipe to signal the end of the input stream,
        // otherwise the process will be **blocked**.
        pipe_stdin.close ();

        // Read the image from the subprocess's stdout
        var pipe_stdout = subprcs.get_stdout_pipe ();
        var output_stream = live_file.replace (null, this.make_backup, this.file_create_flags);
        Utils.write_stream (pipe_stdout, output_stream);

        subprcs.wait ();

        var exit_code = subprcs.get_exit_status ();
        if (exit_code != 0) {
            var pipe_stderr = subprcs.get_stderr_pipe ();
            try { // Try to get the error message from stderr
                var subprcs_error = Utils.get_string_from_file_input_stream (pipe_stderr);
                throw new ExportError.FFMPEG_EXIED_WITH_ERROR (
                    "Command `%s' failed with %d - `%s'",
                    string.joinv (" ", FFMPEG_COMMANDS),
                    exit_code,
                    subprcs_error);
            } catch { // If failed, throw the error without the error message
                throw new ExportError.FFMPEG_EXIED_WITH_ERROR (
                    "Command `%s' failed with %d",
                    string.joinv (" ", FFMPEG_COMMANDS),
                    exit_code);
            }
        }

        // Write the video to the live photo
        video_stream.seek (0, SeekType.SET);
        Utils.write_stream (video_stream, output_stream);

        return video_size;
    }

    public override File export_main_image () throws Error {
        var main_file = File.new_for_commandline_arg (this.main_image_path);
        var live_file = File.new_for_commandline_arg (this.dest);

        if (is_supported_main_image (main_file)) {
            // If the main image is supported, copy it to the live photo
            this.metadata.open_path (this.main_image_path);
            if (! this.export_original_metadata) {
                this.metadata.clear ();
            }

            var output_stream = live_file.replace (null, this.make_backup, this.file_create_flags);
            var main_input_stream = main_file.read ();
            Utils.write_stream (main_input_stream, output_stream);
        } else {
            Reporter.warning_puts ("FormatWarning", "Image format is not supported, converting to JPEG");
            // Convert the main image to supported format
            var main_file_stream = main_file.read ();
            var subprcs = new Subprocess.newv (FFMPEG_COMMANDS,
                SubprocessFlags.STDOUT_PIPE |
                SubprocessFlags.STDERR_PIPE |
                SubprocessFlags.STDIN_PIPE);
            var pipe_stdin = subprcs.get_stdin_pipe ();
            Utils.write_stream (main_file_stream, pipe_stdin);
            pipe_stdin.close ();

            // Read the image from the subprocess's stdout
            var pipe_stdout = subprcs.get_stdout_pipe ();
            var output_stream = live_file.replace (null, this.make_backup, this.file_create_flags);
            Utils.write_stream (pipe_stdout, output_stream);
        }

        return live_file;
    }
}

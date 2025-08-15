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
     * @throws IOError If an I/O error occurs during export
     * @throws ExportError If an export error occurs
     * @throws ProcessError If external process execution fails
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

        // Create a subprocess to run FFmpeg
        Subprocess subprcs;
        try {
            subprcs = new Subprocess.newv (FFMPEG_COMMANDS,
                SubprocessFlags.STDOUT_PIPE |
                SubprocessFlags.STDERR_PIPE |
                SubprocessFlags.STDIN_PIPE);
        } catch (Error e) {
            throw new ProcessError.COMMAND_EXECUTION_FAILED ("Failed to start ffmpeg subprocess: %s", e.message);
        }
        
        // Set the video source
        var pipe_stdin = subprcs.get_stdin_pipe ();
        FileInputStream video_stream;
        try {
            video_stream = video_file.read ();
        } catch (Error e) {
            throw new IOError.FAILED ("Failed to open video file for reading: %s".printf (e.message));
        }
        Utils.write_stream (video_stream, pipe_stdin);
        // Close the pipe to signal the end of the input stream,
        // otherwise the process will be **blocked**.
        pipe_stdin.close ();

        // Read the image from the subprocess's stdout
        var pipe_stdout = subprcs.get_stdout_pipe ();
        FileOutputStream output_stream;
        try {
            output_stream = live_file.replace (null, this.make_backup, this.file_create_flags);
        } catch (Error e) {
            throw new ExportError.FILE_WRITE_ERROR ("Failed to create output live file: %s", e.message);
        }
        Utils.write_stream (pipe_stdout, output_stream);

        try {
            subprcs.wait ();
        } catch (Error e) {
            throw new ProcessError.COMMAND_EXECUTION_FAILED ("FFmpeg process wait failed: %s", e.message);
        }

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
        try {
            video_stream.seek (0, SeekType.SET);
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
            // Convert the main image to supported format
            try {
                var main_file_stream = main_file.read ();
                Subprocess subprcs_conv = new Subprocess.newv (FFMPEG_COMMANDS,
                    SubprocessFlags.STDOUT_PIPE |
                    SubprocessFlags.STDERR_PIPE |
                    SubprocessFlags.STDIN_PIPE);
                var pipe_stdin = subprcs_conv.get_stdin_pipe ();
                Utils.write_stream (main_file_stream, pipe_stdin);
                pipe_stdin.close ();

                // Read the image from the subprocess's stdout
                var pipe_stdout = subprcs_conv.get_stdout_pipe ();
                var output_stream = live_file.replace (null, this.make_backup, this.file_create_flags);
                Utils.write_stream (pipe_stdout, output_stream);
                try {
                    subprcs_conv.wait ();
                } catch (Error e) {
                    throw new ProcessError.COMMAND_EXECUTION_FAILED ("FFmpeg conversion failed: %s", e.message);
                }
            } catch (Error e) {
                throw new ExportError.FILE_WRITE_ERROR ("Failed to convert/copy main image: %s", e.message);
            }
        }

        return live_file;
    }
}

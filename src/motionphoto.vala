/* motionphoto.vala
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

public class MotionPhotoConv.MotionPhoto {
    /* MotionPhoto is a class that represents a motion photo. */

    const int BUFFER_SIZE = 8192;

    string basename;
    string basename_no_ext;
    string extension_name;
    string filename;
    GExiv2.Metadata metadata;
    string dest_dir;
    int64 video_offset;
    bool make_backup;
    FileCreateFlags file_create_flags;
    // string xmp;

    /**
     * Creates a new instance of the MotionPhoto class.
     *
     * @param filename The path to the motion photo file.
     * @param dest_dir The destination directory for the converted motion photo. If not provided, the directory of the input file will be used.
     * @throws Error if an error occurs while retrieving the offset.
     */
    public MotionPhoto (string filename, string? dest_dir = null,
                        FileCreateFlags file_create_flags = FileCreateFlags.REPLACE_DESTINATION, bool make_backup = false) throws Error {
        this.metadata = new GExiv2.Metadata ();
        this.metadata.open_path (filename);
        this.make_backup = make_backup;
        this.file_create_flags = file_create_flags;
        // Get XMP metadata of the image
        // this.xmp = this.metadata.try_get_xmp_packet ();

        this.filename = filename;
        this.basename = Path.get_basename (filename);
        var last_dot = this.basename.last_index_of_char ('.');
        if (last_dot == -1) {
            this.basename_no_ext = this.basename;
            this.extension_name = "jpg"; // Default extension name
        } else {
            this.basename_no_ext = this.basename[:last_dot];
            if (last_dot + 1 < this.basename.length) {
                this.extension_name = this.basename[last_dot + 1:];
            } else {
                this.extension_name = "jpg"; // Default extension name
            }
        }
        if (dest_dir != null) {
            this.dest_dir = dest_dir;
        } else {
            this.dest_dir = Path.get_dirname (filename);
        }

        this.video_offset = this.get_video_offset ();
        if (this.video_offset < 0) {
            throw new NotMotionPhotosError.OFFSET_NOT_FOUND_ERROR ("The offset of the video data in the motion photo is not found.");
        }
        // Remove the XMP metadata of the main image since it is not a motion photo anymore
        // MUST after `get_video_offset` because `get_video_offset` may use the XMP metadata
        this.metadata.clear_xmp ();
    }

    /**
     * Get the offset of the video data in the motion photo.
     *
     * @throws Error if an error occurs while retrieving the offset.
     *
     * @returns the offset of the video data in the motion photo， if the offset is not found, return value < 0.
     */
    inline int64 get_video_offset () throws Error {
        /* Get the offset of the video data in the motion photo. */
        try {
            // Get the offset of the video data from the XMP metadata
            var tag_value = this.metadata.try_get_tag_string ("Xmp.GCamera.MicroVideoOffset");
            if (tag_value != null) {
                int64 reverse_offset = int64.parse (tag_value);
                if (reverse_offset > 0) {
                    var file_size = File.new_for_path (this.filename)
                        .query_info ("standard::size", FileQueryInfoFlags.NONE)
                        .get_size ();
                    return file_size - reverse_offset;
                }
            }
        } catch {
            // If the XMP metadata does not contain the video offset, search for the video tag in the motion photo
            Reporter.warning ("XMPOffsetNotFoundWarning",
                "The XMP metadata does not contain the video offset. Searching for the video tag in the motion photo.");
        }

        const uint8[] VIDEO_TAG = {'f', 't', 'y', 'p'}; // The tag `....ftyp` of MP4 header.
        const int TAG_LENGTH = VIDEO_TAG.length; // The length of the tag.
        int64 offset = -1; // The offset of the video data in the motion photo.
    
        var file = File.new_for_path (this.filename);
        var input_stream = file.read ();
    
        uint8[] buffer = new uint8[BUFFER_SIZE];
        ssize_t bytes_read; // The number of bytes read from the input stream.
        int64 position = 0; // The current position in the input stream.
        uint8[] prev_buffer_tail = new uint8[TAG_LENGTH - 1]; // The tail of the previous buffer to avoid boundary crossing.
    
        while ((bytes_read = input_stream.read (buffer)) > 0) {
            uint8[] search_buffer = new uint8[BUFFER_SIZE + TAG_LENGTH - 1];
            // Copy the tail of the previous buffer to check for boundary crossing
            Memory.copy (search_buffer, prev_buffer_tail, TAG_LENGTH - 1);
            // Copy the current buffer to the search buffer
            Memory.copy ((void*) ((int64) search_buffer + TAG_LENGTH - 1), buffer, bytes_read); // Vala does not support pointer arithmetic, so we have to cast the pointer to int64 first.
    
            ssize_t buffer_offset = 0;
            for (uint i = 0; i < bytes_read; i += 1) {
                if (buffer[i] == VIDEO_TAG[buffer_offset]) {
                    buffer_offset += 1;
                    if (buffer_offset == TAG_LENGTH) {
                        offset = position - TAG_LENGTH + 1;
                        break;
                    }
                } else {
                    buffer_offset = 0;
                }
                position += 1;
            }

            if (offset != -1) {
                break;
            }
            // Store the tail of the current buffer
            Memory.copy (prev_buffer_tail, (void*) ((int64) buffer + bytes_read - TAG_LENGTH - 1), TAG_LENGTH - 1);
        }

        return offset - 4; // The feature of MP4: there is 4 bytes of size before the tag.
    }    
    
    /**
     * Export the main image of the motion photo.
     *
     * @param dest The destination path for the exported main image. If null, a default path will be used.
     * @throws Error if there is an error during the export process.
     * @returns The path of the exported main image.
     */
    public string export_main_image (string? dest = null) throws Error {
        /* Export the main image of the motion photo. */
        // Export the bytes before `video_offset`
        var file = File.new_for_path (this.filename);
        var input_stream = file.read ();
        string main_image_filename;
        if (dest != null) {
            main_image_filename = dest;
        } else {
            if (this.basename.has_prefix ("MVIMG")) {
                // The main image of a motion photo is named as `IMG_YYYYMMDD_HHMMSS.xxx`
                main_image_filename = Path.build_filename (this.dest_dir, "IMG" + this.basename[5:]);
            } else {
                // If the original image is xxx.yyy, the main image is xxx_0.yyy
                main_image_filename = Path.build_filename (this.dest_dir, this.basename_no_ext + "_0." + this.extension_name);
            }
        }

        var output_stream = File.new_for_path (main_image_filename).replace (null, make_backup, file_create_flags);
        // Write the bytes before `video_offset` to the main image file
        var bytes_to_write = this.video_offset;
        while (bytes_to_write > BUFFER_SIZE) {
            var buffer = new uint8[BUFFER_SIZE];
            input_stream.read (buffer);
            output_stream.write (buffer);
            bytes_to_write -= BUFFER_SIZE;
        }
        if (bytes_to_write > 0) {
            var buffer = new uint8[bytes_to_write];
            input_stream.read (buffer);
            output_stream.write (buffer);
        }

        metadata.save_file (main_image_filename);
        return (owned) main_image_filename;
    }

    /**
     * Export the video of the motion photo.
     *
     * @param dest The destination path for the exported video. If not provided, a default path will be used.
     * @throws Error if there is an error during the export process.
     * @returns The path of the exported video file.
     */
    public string export_video (string? dest = null) throws Error {
        /* Export the video of the motion photo. */
        // Export the bytes after `video_offset`
        var file = File.new_for_path (this.filename);
        var input_stream = file.read ();
        string video_filename;
        if (dest != null) {
            video_filename = dest;
        } else {
            if (this.basename.has_prefix ("MVIMG")) {
                // The video of a motion photo is named as `VID_YYYYMMDD_HHMMSS.mp4`
                video_filename = Path.build_filename (this.dest_dir, "VID" + this.basename_no_ext[5:] + ".mp4");
            } else if (this.basename.has_prefix ("IMG")) {
                // If the original image is IMG_YYYYMMDD_HHMMSS.xxx, the video is VID_YYYYMMDD_HHMMSS.mp4
                video_filename = Path.build_filename (this.dest_dir, "VID" + this.basename_no_ext[3:] + ".mp4");
            } else {
                video_filename = Path.build_filename (this.dest_dir, "VID_" + this.basename_no_ext + ".mp4");
            }
        }

        var output_stream = File.new_for_path (video_filename).replace (null, make_backup, file_create_flags);
        // Skip the bytes before `video_offset`
        input_stream.seek (this.video_offset, GLib.SeekType.SET);
        // Write the bytes after `video_offset` to the video file
        var buffer = new uint8[BUFFER_SIZE];
        ssize_t bytes_read;
        while ((bytes_read = input_stream.read (buffer)) > 0) {
            if (bytes_read < BUFFER_SIZE) {
                buffer.length = (int) bytes_read;
                output_stream.write (buffer);
                buffer.length = BUFFER_SIZE;
            } else {
                output_stream.write (buffer);
            }
        }

        return (owned) video_filename;
    }

    /**
     * Split the video into images.
     *
     * @param output_format The format of the output images. If not provided, the default extension name will be used.
     * @param video_source The path to the video source. If not provided or the file does not exist, the video will be exported from the motion photo.
     * @param dest_dir The destination directory where the images will be saved. If not provided, the default destination directory will be used.
     * @param import_metadata Whether to import metadata from the video and save it to the images. Default is true.
     *
     * @throws Error If FFmpeg exits with an error.
     */
    public void splites_images_from_video_ffmpeg (string? output_format = null, string? dest_dir = null,
                                                  bool import_metadata = true) throws Error {
        /* Export the video of the motion photo and split the video into images. */
        string name_to_printf;
        string dest;

        var format = (output_format != null) ? output_format : this.extension_name;

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

        var file = File.new_for_path (this.filename);
        var input_stream = file.read ();
        // Skip the bytes before `video_offset`
        input_stream.seek (this.video_offset, GLib.SeekType.SET);

        uint8[] buffer = new uint8[BUFFER_SIZE];
        ssize_t bytes_read;
        while ((bytes_read = input_stream.read (buffer)) > 0) {
            if (bytes_read < BUFFER_SIZE) {
                buffer.length = (int) bytes_read;
                pipe_stdin.write (buffer);
                buffer.length = BUFFER_SIZE;
            } else {
                pipe_stdin.write (buffer);
            }
        }
        pipe_stdin.close (); // Close the pipe to signal the end of the input stream
        
        subprcs.wait ();
        var exit_code = subprcs.get_exit_status ();
        var subprcs_output = get_string_from_file_input_stream (pipe_stdout);
        var subprcs_error = get_string_from_file_input_stream (pipe_stderr);

        if (exit_code != 0) {
            throw new ConvertError.FFMPEG_EXIED_WITH_ERROR ("FFmpeg exit with %d - `%s'", exit_code, subprcs_error);
        }

        if (import_metadata) {
            MatchInfo match_info;
            var re_frame = /.*frame=\s*(\d+)/s;
            re_frame.match (subprcs_output, 0, out match_info);
            if (match_info.matches ()) {
                // Set the metadata of the images
                var num_frames = int64.parse (match_info.fetch (1));
                for (int i = 1; i < num_frames + 1; i += 1) {
                    var image_filename = Path.build_filename (this.dest_dir, name_to_printf.printf (i));
                    metadata.save_file (image_filename);
                }
            } else {
                Reporter.warning ("FFmpegOutputParseWarning", "Failed to parse the output of FFmpeg.");
            }
        }
    }

    //  static string get_unique_temp_filename (string tpl) throws FileError {
    //      string temp_filename;

    //      var fd = FileUtils.open_tmp (tpl, out temp_filename);
    //      FileUtils.close(fd);

    //      return temp_filename;
    //  }

    static string get_string_from_file_input_stream (InputStream input_stream) throws IOError {
        StringBuilder builder = null;
        uint8[] buffer = new uint8[BUFFER_SIZE + 1]; // allocate one more byte for the null terminator
        buffer.length = BUFFER_SIZE; // Set the length of the buffer to BUFFER_SIZE
        ssize_t bytes_read;

        while ((bytes_read = input_stream.read (buffer)) > 0) {
            buffer[bytes_read] = '\0'; // Add a null terminator to the end of the string
            if (builder == null) {
                builder = new StringBuilder.from_buffer ((char[]) buffer);
            } else {
                builder.append ((string) buffer);
            }
        }

        return (builder != null) ? builder.free_and_steal () : "";
    }
}

public errordomain MotionPhotoConv.NotMotionPhotosError {
    OFFSET_NOT_FOUND_ERROR, // The offset of the video data in the motion photo is not found.
}

public errordomain MotionPhotoConv.ConvertError {
    FFMPEG_EXIED_WITH_ERROR, // FFmpeg failed to split the video into images.
}

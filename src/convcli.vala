/* convcli.vala
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

[Compact (opaque = true)]
class MotionPhotoConv.CLI {

    static bool show_help = false;
    static bool show_version = false;
    static string? operation = null;
    static int color_level = 1;
    static string? main_image_path = null;
    static string? video_path = null;
    static string? motion_photo_path = null;
    static string? dest_dir = null;
    static string? img_format = null;
    static bool export_metadata = true;
    static bool video_to_photos = false;

    const OptionEntry[] options = {
        { "help", 'h', OptionFlags.NONE, OptionArg.NONE, ref show_help, "Show help message", null },
        { "version", 'v', OptionFlags.NONE, OptionArg.NONE, ref show_version, "Display version number", null },
        { "operation", 'p', OptionFlags.NONE, OptionArg.STRING, ref operation, "The operation to perform, options are 'make' or 'extract'", "OPERATION" },
        { "image", 'i', OptionFlags.NONE, OptionArg.FILENAME, ref main_image_path, "The path to the main static image file", "PATH" },
        { "video", 'm', OptionFlags.NONE, OptionArg.FILENAME, ref video_path, "The path to the video file", "PATH" },
        { "motion-photo", 'o', OptionFlags.NONE, OptionArg.FILENAME, ref motion_photo_path, "The destination path for the motion image file. If not provided in 'make' mode, a default destination path will be generated based on the main static image file", "PATH" },
        { "dest-dir", 'd', OptionFlags.NONE, OptionArg.FILENAME, ref dest_dir, "The destination directory to export", "PATH" },
        { "export-metadata", '\0', OptionFlags.NONE, OptionArg.NONE, ref export_metadata, "Export metadata (default)", null },
        { "no-export-metadata", '\0', OptionFlags.REVERSE, OptionArg.NONE, ref export_metadata, "Do not export metadata", null },
        { "video-to-photos", '\0', OptionFlags.NONE, OptionArg.NONE, ref video_to_photos, "Export every frame of video as a photo", null },
        { "img-format", 'f', OptionFlags.NONE, OptionArg.STRING, ref img_format, "The format of the image exported from video", "FORMAT" },
        { "color", 'c', OptionFlags.NONE, OptionArg.INT, ref color_level, "Color level, 0 for no color, 1 for auto, 2 for always, defaults to 1", "LEVEL" },
        null
    };

    static int main (string[] original_args) {
        // Compatibility for Windows and Unix
        if (Intl.setlocale (LocaleCategory.ALL, ".UTF-8") == null) {
            Intl.setlocale ();
        }

#if WINDOWS
        var args = Win32.get_command_line ();
#else
        var args = strdupv (original_args);
#endif
        var opt_context = new OptionContext ("- Make or Extract Motion Photos");
        // DO NOT use the default help option provided by g_print
        // g_print will force to convert character set to windows's code page
        // which is imcompatible windows's bash, zsh, etc.
        opt_context.set_help_enabled (false);

        opt_context.add_main_entries (options, null);
        try {
            opt_context.parse_strv (ref args);
        } catch (OptionError e) {
            Reporter.error ("OptionError", e.message);
            stderr.printf ("\n%s", opt_context.get_help (true, null));
            return 1;
        }

        switch (color_level) {
        case 0:
            Reporter.color_setting = Reporter.ColorSettings.NEVER;
            break;
        case 1:
            Reporter.color_setting = Reporter.ColorSettings.AUTO;
            break;
        case 2:
            Reporter.color_setting = Reporter.ColorSettings.ALWAYS;
            break;
        default:
            Reporter.warning ("OptionWarning", "invalid color level, fallback to level 1 (auto)");
            Reporter.color_setting = Reporter.ColorSettings.AUTO;
            break;
        }

        if (show_help) {
            stderr.puts (opt_context.get_help (true, null));
            return 0;
        }

        if (show_version) {
            Reporter.info ("Motion Photo Converter", VERSION);
            return 0;
        }

        if (operation == null) {
            Reporter.error ("OptionError", "`--operation' is required");
            stderr.printf ("\n%s", opt_context.get_help (true, null));
            return 1;
        }

        if (operation == "extract") {
            if (motion_photo_path == null) {
                Reporter.error ("OptionError", "`--image' is required in 'extract' mode");
                stderr.printf ("\n%s", opt_context.get_help (true, null));
                return 1;
            }

            try {
                var motion_photo = new MotionPhoto (motion_photo_path, dest_dir);
                motion_photo.export_main_image (main_image_path);
                motion_photo.export_video (video_path);

                if (video_to_photos) {
                    motion_photo.splites_images_from_video_ffmpeg (img_format, dest_dir, export_metadata);
                }
            } catch (NotMotionPhotosError e) {
                Reporter.error ("NotMotionPhotosError", e.message);
                return 1;
            } catch (Error e) {
                Reporter.error ("Error", e.message);
                return 1;
            }
        } else if (operation == "make") {
            if (main_image_path == null || video_path == null) {
                Reporter.error ("OptionError", "`--image' and `--video' are required in 'make' mode");
                stderr.printf ("\n%s", opt_context.get_help (true, null));
                return 1;
            }

            try {
                var motion_maker = new MotionMaker (main_image_path, video_path, motion_photo_path, export_metadata);
                motion_maker.export (motion_photo_path);
            } catch (IOError e) {
                Reporter.error ("IOError", e.message);
                return 1;
            } catch (Error e) {
                Reporter.error ("Error", e.message);
                return 1;
            }
        } else {
            Reporter.error ("OptionError", "invalid operation, options are 'make' or 'extract'");
            stderr.printf ("\n%s", opt_context.get_help (true, null));
            return 1;
        }

        return 0;
    }
}

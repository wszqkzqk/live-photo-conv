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
    static bool make_motion_photo = false;
    static int color_level = 1;
    static string? main_image_path = null;
    static string? video_path = null;
    static string? motion_photo_path = null;
    static string? dest_dir = null;
    static string? img_format = null;
    static bool export_metadata = true;
    static bool frame_to_photo = false;
    static bool minimal_export = false;

    const OptionEntry[] options = {
        { "help", 'h', OptionFlags.NONE, OptionArg.NONE, ref show_help, "Show help message", null },
        { "version", 'v', OptionFlags.NONE, OptionArg.NONE, ref show_version, "Display version number", null },
        { "make", 'g', OptionFlags.NONE, OptionArg.NONE, ref make_motion_photo, "Make a motion photo", null },
        { "extract", 'e', OptionFlags.REVERSE, OptionArg.NONE, ref make_motion_photo, "Extract a motion photo (default)", null },
        { "image", 'i', OptionFlags.NONE, OptionArg.FILENAME, ref main_image_path, "The path to the main static image file", "PATH" },
        { "video", 'm', OptionFlags.NONE, OptionArg.FILENAME, ref video_path, "The path to the video file", "PATH" },
        { "motion-photo", 'p', OptionFlags.NONE, OptionArg.FILENAME, ref motion_photo_path, "The destination path for the motion image file. If not provided in 'make' mode, a default destination path will be generated based on the main static image file", "PATH" },
        { "dest-dir", 'd', OptionFlags.NONE, OptionArg.FILENAME, ref dest_dir, "The destination directory to export", "PATH" },
        { "export-metadata", '\0', OptionFlags.NONE, OptionArg.NONE, ref export_metadata, "Export metadata (default)", null },
        { "no-export-metadata", '\0', OptionFlags.REVERSE, OptionArg.NONE, ref export_metadata, "Do not export metadata", null },
        { "frame-to-photos", '\0', OptionFlags.NONE, OptionArg.NONE, ref frame_to_photo, "Export every frame of a motion photo's video as a photo", null },
        { "img-format", 'f', OptionFlags.NONE, OptionArg.STRING, ref img_format, "The format of the image exported from video", "FORMAT" },
        { "minimal", '\0', OptionFlags.NONE, OptionArg.NONE, ref minimal_export, "Minimal metadata export, ignore unspecified exports", null },
        { "color", '\0', OptionFlags.NONE, OptionArg.INT, ref color_level, "Color level, 0 for no color, 1 for auto, 2 for always, defaults to 1", "LEVEL" },
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
        var opt_context = new OptionContext ("- Extract or Make Motion Photos");
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

        if (make_motion_photo) {
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
            if (motion_photo_path == null) {
                Reporter.error ("OptionError", "`--image' is required in 'extract' mode");
                stderr.printf ("\n%s", opt_context.get_help (true, null));
                return 1;
            }

            try {
                var motion_photo = new MotionPhotoFFmpeg (motion_photo_path, dest_dir, export_metadata);
                if (!minimal_export) {
                    motion_photo.export_main_image (main_image_path);
                    motion_photo.export_video (video_path);
                } else if (main_image_path != null) {
                    motion_photo.export_main_image (main_image_path);
                } else if (video_path != null) {
                    motion_photo.export_video (video_path);
                }

                if (frame_to_photo) {
                    motion_photo.splites_images_from_video (img_format, dest_dir);
                }
            } catch (NotMotionPhotosError e) {
                Reporter.error ("NotMotionPhotosError", e.message);
                return 1;
            } catch (Error e) {
                Reporter.error ("Error", e.message);
                return 1;
            }
        }

        return 0;
    }
}

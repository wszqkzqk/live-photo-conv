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

[Compact (opaque = true)]
class LivePhotoConv.Main {

    static bool show_help = false;
    static bool show_version = false;
    static bool make_live_photo = false;
    static bool repair_live_photo = false;
    static bool force_repair = false;
    static uint repair_with_video_size = 0;
    static int color_level = 1;
    static string? main_image_path = null;
    static string? video_path = null;
    static string? live_photo_path = null;
    static string? dest_dir = null;
    static string? img_format = null;
    static bool export_metadata = true;
    static bool frame_to_photo = false;
    static bool minimal_export = false;
    static int threads = 0;
#if ENABLE_GST
    static bool use_ffmpeg = false;
#endif

    const OptionEntry[] options = {
        { "help", 'h', OptionFlags.NONE, OptionArg.NONE, ref show_help, "Show help message", null },
        { "version", 'v', OptionFlags.NONE, OptionArg.NONE, ref show_version, "Display version number", null },
        { "color", '\0', OptionFlags.NONE, OptionArg.INT, ref color_level, "Color level of log, 0 for no color, 1 for auto, 2 for always, defaults to 1", "LEVEL" },
        { "make", 'g', OptionFlags.NONE, OptionArg.NONE, ref make_live_photo, "Make a live photo", null },
        { "extract", 'e', OptionFlags.REVERSE, OptionArg.NONE, ref make_live_photo, "Extract a live photo (default)", null },
        { "repair", 'r', OptionFlags.NONE, OptionArg.NONE, ref repair_live_photo, "Repair a live photo from missing XMP metadata", null },
        { "force-repair", '\0', OptionFlags.NONE, OptionArg.NONE, ref force_repair, "Force repair a live photo (force update video offset in XMP metadata)", null },
        { "repair-with-video-size", '\0', OptionFlags.NONE, OptionArg.INT, ref repair_with_video_size, "Force repair a live photo with the specified video size", "SIZE" },
        { "image", 'i', OptionFlags.NONE, OptionArg.FILENAME, ref main_image_path, "The path to the main static image file", "PATH" },
        { "video", 'm', OptionFlags.NONE, OptionArg.FILENAME, ref video_path, "The path to the video file", "PATH" },
        { "live-photo", 'p', OptionFlags.NONE, OptionArg.FILENAME, ref live_photo_path, "The destination path for the live image file. If not provided in 'make' mode, a default destination path will be generated based on the main static image file", "PATH" },
        { "dest-dir", 'd', OptionFlags.NONE, OptionArg.FILENAME, ref dest_dir, "The destination directory to export", "PATH" },
        { "export-metadata", '\0', OptionFlags.NONE, OptionArg.NONE, ref export_metadata, "Export metadata (default)", null },
        { "no-export-metadata", '\0', OptionFlags.REVERSE, OptionArg.NONE, ref export_metadata, "Do not export metadata", null },
        { "frame-to-photos", '\0', OptionFlags.NONE, OptionArg.NONE, ref frame_to_photo, "Export every frame of a live photo's video as a photo", null },
        { "img-format", 'f', OptionFlags.NONE, OptionArg.STRING, ref img_format, "The format of the image exported from video", "FORMAT" },
        { "minimal", '\0', OptionFlags.NONE, OptionArg.NONE, ref minimal_export, "Minimal metadata export, ignore unspecified exports", null },
        { "threads", 'T', OptionFlags.NONE, OptionArg.INT, ref threads, "Number of threads to use for extracting, 0 for auto (not work in FFmpeg mode)", "NUM" },
#if ENABLE_GST
        { "use-ffmpeg", '\0', OptionFlags.NONE, OptionArg.NONE, ref use_ffmpeg, "Use FFmpeg to extract insdead of GStreamer", null },
        { "use-gst", '\0', OptionFlags.REVERSE, OptionArg.NONE, ref use_ffmpeg, "Use GStreamer to extract insdead of FFmpeg (default)", null },
#endif
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
        var opt_context = new OptionContext ("- Extract, Repair or Make Live Photos");
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
            Reporter.info ("Live Photo Converter", VERSION);
            return 0;
        }

        if (make_live_photo) {
            if (main_image_path == null || video_path == null) {
                Reporter.error ("OptionError", "`--image' and `--video' are required in 'make' mode");
                stderr.printf ("\n%s", opt_context.get_help (true, null));
                return 1;
            }

            try {
                var live_maker = new LiveMaker (main_image_path, video_path, live_photo_path, export_metadata);
                live_maker.export (live_photo_path);
            } catch (IOError e) {
                Reporter.error ("IOError", e.message);
                return 1;
            } catch (Error e) {
                Reporter.error ("Error", e.message);
                return 1;
            }
        } else {
            if (live_photo_path == null) {
                Reporter.error ("OptionError", "`--live-photo' is required in 'extract' and 'repair' mode");
                stderr.printf ("\n%s", opt_context.get_help (true, null));
                return 1;
            }

            try {
#if ENABLE_GST
                LivePhoto live_photo;
                if (use_ffmpeg) {
                    live_photo = new LivePhotoFFmpeg (live_photo_path, dest_dir, export_metadata);
                } else {
                    live_photo = new LivePhotoGst (live_photo_path, dest_dir, export_metadata);
                }
#else
                LivePhoto live_photo = new LivePhotoFFmpeg (live_photo_path, dest_dir, export_metadata);
#endif
                if (repair_live_photo || force_repair || repair_with_video_size > 0) {
                    // Default minimal export for repair mode
                    minimal_export = true;
                    live_photo.repair_live_metadata (force_repair, repair_with_video_size);
                }

                if (!minimal_export) {
                    live_photo.export_main_image (main_image_path);
                    live_photo.export_video (video_path);
                } else {
                    if (main_image_path != null) {
                        live_photo.export_main_image (main_image_path);
                    }
                    if (video_path != null) {
                        live_photo.export_video (video_path);
                    }
                }

                if (frame_to_photo) {
                    live_photo.splites_images_from_video (img_format, dest_dir, threads);
                }
            } catch (NotLivePhotosError e) {
                Reporter.error ("NotLivePhotosError", e.message);
                return 1;
            } catch (Error e) {
                Reporter.error ("Error", e.message);
                return 1;
            }
        }

        return 0;
    }
}

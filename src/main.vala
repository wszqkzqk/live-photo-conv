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

    static bool require_live_photo = true;
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

    // Options for live-photo-make mode
    const OptionEntry[] MAKE_OPTIONS = {
        { "help", 'h', OptionFlags.NONE, OptionArg.NONE, ref show_help, "Show help message", null },
        { "version", '\0', OptionFlags.NONE, OptionArg.NONE, ref show_version, "Display version number", null },
        { "color", '\0', OptionFlags.NONE, OptionArg.INT, ref color_level, "Color level of log, 0 for no color, 1 for auto, 2 for always, defaults to 1", "LEVEL" },
        { "image", 'i', OptionFlags.NONE, OptionArg.FILENAME, ref main_image_path, "The path to the main static image file", "PATH" },
        { "video", 'm', OptionFlags.NONE, OptionArg.FILENAME, ref video_path, "The path to the video file (required)", "PATH" },
        { "output", 'o', OptionFlags.NONE, OptionArg.FILENAME, ref live_photo_path, "The output live photo file path", "PATH" },
        { "export-metadata", '\0', OptionFlags.NONE, OptionArg.NONE, ref export_metadata, "Export metadata (default)", null },
        { "drop-metadata", '\0', OptionFlags.REVERSE, OptionArg.NONE, ref export_metadata, "Do not export metadata", null },
#if ENABLE_GST
        { "use-ffmpeg", '\0', OptionFlags.NONE, OptionArg.NONE, ref use_ffmpeg, "Use FFmpeg to extract instead of GStreamer", null },
        { "use-gst", '\0', OptionFlags.REVERSE, OptionArg.NONE, ref use_ffmpeg, "Use GStreamer to extract instead of FFmpeg (default)", null },
#endif
        null
    };

    // Options for live-photo-extract mode
    const OptionEntry[] EXTRACT_OPTIONS = {
        { "help", 'h', OptionFlags.NONE, OptionArg.NONE, ref show_help, "Show help message", null },
        { "version", '\0', OptionFlags.NONE, OptionArg.NONE, ref show_version, "Display version number", null },
        { "color", '\0', OptionFlags.NONE, OptionArg.INT, ref color_level, "Color level of log, 0 for no color, 1 for auto, 2 for always, defaults to 1", "LEVEL" },
        { "live-photo", 'p', OptionFlags.NONE, OptionArg.FILENAME, ref live_photo_path, "The live photo file to extract (required)", "PATH" },
        { "dest-dir", 'd', OptionFlags.NONE, OptionArg.FILENAME, ref dest_dir, "The destination directory to export", "PATH" },
        { "image", 'i', OptionFlags.NONE, OptionArg.FILENAME, ref main_image_path, "The path to export the main image", "PATH" },
        { "video", 'm', OptionFlags.NONE, OptionArg.FILENAME, ref video_path, "The path to export the video", "PATH" },
        { "export-metadata", '\0', OptionFlags.NONE, OptionArg.NONE, ref export_metadata, "Export metadata (default)", null },
        { "drop-metadata", '\0', OptionFlags.REVERSE, OptionArg.NONE, ref export_metadata, "Do not export metadata", null },
        { "frame-to-photos", '\0', OptionFlags.NONE, OptionArg.NONE, ref frame_to_photo, "Export every frame of the video as photos", null },
        { "img-format", 'f', OptionFlags.NONE, OptionArg.STRING, ref img_format, "The format of the image exported from video", "FORMAT" },
        { "threads", 'T', OptionFlags.NONE, OptionArg.INT, ref threads, "Number of threads to use for extracting, 0 for auto", "NUM" },
#if ENABLE_GST
        { "use-ffmpeg", '\0', OptionFlags.NONE, OptionArg.NONE, ref use_ffmpeg, "Use FFmpeg to extract instead of GStreamer", null },
        { "use-gst", '\0', OptionFlags.REVERSE, OptionArg.NONE, ref use_ffmpeg, "Use GStreamer to extract instead of FFmpeg (default)", null },
#endif
        null
    };

    // Options for live-photo-repair mode
    const OptionEntry[] REPAIR_OPTIONS = {
        { "help", 'h', OptionFlags.NONE, OptionArg.NONE, ref show_help, "Show help message", null },
        { "version", '\0', OptionFlags.NONE, OptionArg.NONE, ref show_version, "Display version number", null },
        { "color", '\0', OptionFlags.NONE, OptionArg.INT, ref color_level, "Color level of log, 0 for no color, 1 for auto, 2 for always, defaults to 1", "LEVEL" },
        { "live-photo", 'p', OptionFlags.NONE, OptionArg.FILENAME, ref live_photo_path, "The live photo file to repair (required)", "PATH" },
        { "force", 'f', OptionFlags.NONE, OptionArg.NONE, ref force_repair, "Force to update video offset in XMP metadata and repair", null },
        { "video-size", 's', OptionFlags.NONE, OptionArg.INT, ref repair_with_video_size, "Force repair with the specified video size", "SIZE" },
        null
    };

    // Full options for generic mode
    const OptionEntry[] FULL_OPTIONS = {
        { "help", 'h', OptionFlags.NONE, OptionArg.NONE, ref show_help, "Show help message", null },
        { "version", 'v', OptionFlags.NONE, OptionArg.NONE, ref show_version, "Display version number", null },
        { "color", '\0', OptionFlags.NONE, OptionArg.INT, ref color_level, "Color level of log, 0 for no color, 1 for auto, 2 for always, defaults to 1", "LEVEL" },
        { "make", 'g', OptionFlags.REVERSE, OptionArg.NONE, ref require_live_photo, "Make a live photo", null },
        { "extract", 'e', OptionFlags.NONE, OptionArg.NONE, ref require_live_photo, "Extract a live photo (default)", null },
        { "repair", 'r', OptionFlags.NONE, OptionArg.NONE, ref repair_live_photo, "Repair a live photo from missing XMP metadata", null },
        { "force-repair", '\0', OptionFlags.NONE, OptionArg.NONE, ref force_repair, "Force repair a live photo (force update video offset in XMP metadata)", null },
        { "repair-with-video-size", '\0', OptionFlags.NONE, OptionArg.INT, ref repair_with_video_size, "Force repair a live photo with the specified video size", "SIZE" },
        { "image", 'i', OptionFlags.NONE, OptionArg.FILENAME, ref main_image_path, "The path to the main static image file", "PATH" },
        { "video", 'm', OptionFlags.NONE, OptionArg.FILENAME, ref video_path, "The path to the video file", "PATH" },
        { "live-photo", 'p', OptionFlags.NONE, OptionArg.FILENAME, ref live_photo_path, "The destination path for the live image file. If not provided in 'make' mode, a default destination path will be generated based on the main static image file", "PATH" },
        { "dest-dir", 'd', OptionFlags.NONE, OptionArg.FILENAME, ref dest_dir, "The destination directory to export", "PATH" },
        { "export-metadata", '\0', OptionFlags.NONE, OptionArg.NONE, ref export_metadata, "Export metadata (default)", null },
        { "drop-metadata", '\0', OptionFlags.REVERSE, OptionArg.NONE, ref export_metadata, "Do not export metadata", null },
        { "frame-to-photos", '\0', OptionFlags.NONE, OptionArg.NONE, ref frame_to_photo, "Export every frame of a live photo's video as a photo", null },
        { "img-format", 'f', OptionFlags.NONE, OptionArg.STRING, ref img_format, "The format of the image exported from video", "FORMAT" },
        { "minimal", '\0', OptionFlags.NONE, OptionArg.NONE, ref minimal_export, "Minimal metadata export, ignore unspecified exports", null },
        { "threads", 'T', OptionFlags.NONE, OptionArg.INT, ref threads, "Number of threads to use for extracting, 0 for auto (not work in FFmpeg mode)", "NUM" },
#if ENABLE_GST
        { "use-ffmpeg", '\0', OptionFlags.NONE, OptionArg.NONE, ref use_ffmpeg, "Use FFmpeg to extract instead of GStreamer", null },
        { "use-gst", '\0', OptionFlags.REVERSE, OptionArg.NONE, ref use_ffmpeg, "Use GStreamer to extract instead of FFmpeg (default)", null },
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

        // Determine program mode based on executable name
        string program_name = Path.get_basename (args[0]).ascii_down ();
        OptionEntry[] options;
        string help_description;

        if (program_name.has_prefix ("live-photo-make")) {
            // Make mode - simplified CLI for creating live photos
            require_live_photo = false;
            options = MAKE_OPTIONS;
            help_description = "- Make Live Photos from image and video files";
        } else if (program_name.has_prefix ("live-photo-extract")) {
            // Extract mode - simplified CLI for extracting live photos
            options = EXTRACT_OPTIONS;
            help_description = "- Extract images and videos from Live Photos";
        } else if (program_name.has_prefix ("live-photo-repair")) {
            // Repair mode - simplified CLI for repairing live photos
            repair_live_photo = true;
            options = REPAIR_OPTIONS;
            help_description = "- Repair Live Photos with missing or corrupted XMP metadata";
        } else {
            // Generic mode - full CLI options
            options = FULL_OPTIONS;
            help_description = "- Extract, Repair or Make Live Photos";
        }
        
        var opt_context = new OptionContext (help_description);
        // DO NOT use the default help option provided by g_print
        // g_print will force to convert character set to windows's code page
        // which is imcompatible windows's bash, zsh, etc.
        opt_context.set_help_enabled (false);

        opt_context.add_main_entries (options, null);
        try {
            opt_context.parse_strv (ref args);
        } catch (OptionError e) {
            Reporter.error_puts ("OptionError", e.message);
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
            Reporter.warning_puts ("OptionWarning", "invalid color level, fallback to level 1 (auto)");
            Reporter.color_setting = Reporter.ColorSettings.AUTO;
            break;
        }

        if (show_help) {
            stderr.puts (opt_context.get_help (true, null));
            return 0;
        }

        if (show_version) {
            Reporter.info_puts ("Live Photo Converter", VERSION);
            return 0;
        }

        if (require_live_photo) {
             // 'extract' and 'repair' modes require a live photo path
            if (live_photo_path == null) {
                Reporter.error_puts ("OptionError", "`--live-photo' is required for this mode");
                stderr.printf ("\n%s", opt_context.get_help (true, null));
                return 1;
            }

            try {
                if (repair_live_photo) {
                    // Repair mode: perform repair first and enable minimal export
                    // so no image/video is exported unless user explicitly set paths.
                    minimal_export = true;
                    live_photo_repair ();
                }

                live_photo_extract ();
            } catch (NotLivePhotosError e) {
                Reporter.error_puts ("NotLivePhotosError", e.message);
                return 1;
            } catch (Error e) {
                Reporter.error_puts ("Error", e.message);
                return 1;
            }

            return 0;
        }

        // require_live_photo is false: making a new live photo, requires video path
        if (video_path == null) {
            Reporter.error_puts ("OptionError", "`--video' is required for this mode");
            stderr.printf ("\n%s", opt_context.get_help (true, null));
            return 1;
        }

        try {
            live_photo_make ();
        } catch (IOError e) {
            Reporter.error_puts ("IOError", e.message);
            return 1;
        } catch (Error e) {
            Reporter.error_puts ("Error", e.message);
            return 1;
        }

        return 0;
    }

    static LivePhoto prepare_live_photo_obj () throws Error {
        LivePhoto live_photo;
#if ENABLE_GST
        if (use_ffmpeg) {
            live_photo = new LivePhotoFFmpeg (live_photo_path, dest_dir) {
                export_original_metadata = export_metadata,
            };
        } else {
            live_photo = new LivePhotoGst (live_photo_path, dest_dir) {
                export_original_metadata = export_metadata,
            };
        }
#else
        live_photo = new LivePhotoFFmpeg (live_photo_path, dest_dir) {
            export_original_metadata = export_metadata,
        };
#endif
        return live_photo;
    }

    static void live_photo_make () throws Error {
#if ENABLE_GST
        LiveMaker live_maker;
        if (use_ffmpeg) {
            live_maker = new LiveMakerFFmpeg (video_path, main_image_path, live_photo_path)  {
                export_original_metadata = export_metadata,
            };
        } else {
            live_maker = new LiveMakerGst (video_path, main_image_path, live_photo_path)  {
                export_original_metadata = export_metadata,
            };
        }
#else
        LiveMaker live_maker = new LiveMakerFFmpeg (video_path, main_image_path, live_photo_path)  {
            export_original_metadata = export_metadata,
        };
#endif
        live_maker.export ();
    }

    static void live_photo_repair () throws Error {
        LivePhoto live_photo = prepare_live_photo_obj ();
        live_photo.repair_live_metadata (force_repair, repair_with_video_size);
    }

    static void live_photo_extract () throws Error {
        LivePhoto live_photo = prepare_live_photo_obj ();

        if ((!minimal_export) || main_image_path != null) {
            live_photo.export_main_image (main_image_path);
        }
        if ((!minimal_export) || video_path != null) {
            live_photo.export_video (video_path);
        }
        if (frame_to_photo) {
            live_photo.split_images_from_video (img_format, dest_dir, threads);
        }
    }
}

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
class LivePhotoConv.CopyImgMeta {

    static bool show_help = false;
    static bool show_version = false;
    static int color_level = 1;
    static bool exclude_exif = false;
    static bool exclude_xmp = false;
    static bool exclude_iptc = false;

    const OptionEntry[] options = {
        { "help", 'h', OptionFlags.NONE, OptionArg.NONE, ref show_help, "Show help message", null },
        { "version", 'v', OptionFlags.NONE, OptionArg.NONE, ref show_version, "Display version number", null },
        { "color", '\0', OptionFlags.NONE, OptionArg.INT, ref color_level, "Color level of log, 0 for no color, 1 for auto, 2 for always, defaults to 1", "LEVEL" },
        { "exclude-exif", '\0', OptionFlags.NONE, OptionArg.NONE, ref exclude_exif, "Do not copy EXIF data", null },
        { "with-exif", '\0', OptionFlags.REVERSE, OptionArg.NONE, ref exclude_exif, "Copy EXIF data (default)", null },
        { "exclude-xmp", '\0', OptionFlags.NONE, OptionArg.NONE, ref exclude_xmp, "Do not copy XMP data", null },
        { "with-xmp", '\0', OptionFlags.REVERSE, OptionArg.NONE, ref exclude_xmp, "Copy XMP data (default)", null },
        { "exclude-iptc", '\0', OptionFlags.NONE, OptionArg.NONE, ref exclude_iptc, "Do not copy IPTC data", null },
        { "with-iptc", '\0', OptionFlags.REVERSE, OptionArg.NONE, ref exclude_iptc, "Copy IPTC data (default)", null },
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
        var opt_context = new OptionContext ("<exif-source-img> <dest-img> - Copy all metadata from one image to another");
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
            Reporter.info_puts ("EXIF Copy Tool", VERSION);
            return 0;
        }

        // Note that args[0] is the program path
        if (args.length != 3) {
            Reporter.error_puts ("ArgumentError",
                (args.length < 3) ? "Two image files are required" : "Too many arguments");
            stderr.printf ("\n%s", opt_context.get_help (true, null));
            return 1;
        }

        unowned var source_path = args[1];
        unowned var dest_path = args[2];

        var metadata = new GExiv2.Metadata ();
        try {
            metadata.open_path (source_path);

            if (exclude_exif) {
                metadata.clear_exif ();
            }
            if (exclude_xmp) {
                metadata.clear_xmp ();
            }
            if (exclude_iptc) {
                metadata.clear_iptc ();
            }

            metadata.save_file (dest_path);
            Reporter.info ("MetadataCopied", "EXIF data copied from `%s' to `%s'", source_path, dest_path);
        } catch (Error e) {
            Reporter.error_puts ("MetadataError", e.message);
            return 1;
        }

        return 0;
    }
}

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
    static string color_setting_str;

    const OptionEntry[] options = {
        { "help", 'h', OptionFlags.NONE, OptionArg.NONE, ref show_help, "Show help message", null },
        { "version", 'v', OptionFlags.NONE, OptionArg.NONE, ref show_version, "Display version number", null },
        { "color", '\0', OptionFlags.NONE, OptionArg.STRING, ref color_setting_str, "Enable color output, options are 'always', 'never', or 'auto'", "WHEN" },
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
        var opt_context = new OptionContext ("command [:::|::::] [arguments]");
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

        if (color_setting_str != null) {
            color_setting_str = color_setting_str.ascii_down ();
            switch (color_setting_str) {
            case "always":
                Reporter.color_setting = Reporter.ColorSettings.ALWAYS;
                break;
            case "never":
                Reporter.color_setting = Reporter.ColorSettings.NEVER;
                break;
            case "auto":
                Reporter.color_setting = Reporter.ColorSettings.AUTO;
                break;
            default:
                Reporter.warning ("OptionWarning", "invalid color setting, fallback to auto");
                Reporter.color_setting = Reporter.ColorSettings.AUTO;
                break;
            }
        }

        if (show_help) {
            stderr.puts (opt_context.get_help (true, null));
            return 0;
        }

        if (show_version) {
            Reporter.info ("Motion Photo Converter", VERSION);
            return 0;
        }

        return 0;
    }
}

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
 * @class LivePhotoConv.Reporter
 * @brief A class for reporting messages, errors, and warnings with optional color coding.
 *
 * The Reporter class provides methods to report failed commands, general messages,
 * errors, and warnings. It supports color-coded output based on the terminal's capabilities.
*/
[Compact (opaque = true)]
public class LivePhotoConv.Reporter {

    public static ColorSettings color_setting = ColorSettings.AUTO;

    [CCode (cheader_filename = "platformbindings.h", cname = "is_a_tty")]
    public extern static bool isatty (int fd);
    [CCode (cheader_filename = "platformbindings.h", cname = "get_console_width")]
    public extern static int get_console_width ();

    [CCode (has_type_id = false)]
    public enum ColorSettings {
        NEVER,
        ALWAYS,
        AUTO;

        public inline bool to_bool () {
            switch (this) {
            case NEVER: return false;
            case ALWAYS: return true;
            default: return Log.writer_supports_color (stderr.fileno ());
            }
        }
    }

    [CCode (has_type_id = false)]
    public enum EscapeCode {
        RESET,
        RED,
        GREEN,
        YELLOW,
        BLUE,
        MAGENTA,
        CYAN,
        WHITE,
        BOLD,
        UNDERLINE,
        BLINK,
        DIM,
        HIDDEN,
        INVERT;

        // Colors
        public const string ANSI_RED = "\x1b[31m";
        public const string ANSI_GREEN = "\x1b[32m";
        public const string ANSI_YELLOW = "\x1b[33m";
        public const string ANSI_BLUE = "\x1b[34m";
        public const string ANSI_MAGENTA = "\x1b[35m";
        public const string ANSI_CYAN = "\x1b[36m";
        public const string ANSI_WHITE = "\x1b[37m";
        // Effects
        public const string ANSI_BOLD = "\x1b[1m";
        public const string ANSI_UNDERLINE = "\x1b[4m";
        public const string ANSI_BLINK = "\x1b[5m";
        public const string ANSI_DIM = "\x1b[2m";
        public const string ANSI_HIDDEN = "\x1b[8m";
        public const string ANSI_INVERT = "\x1b[7m";
        public const string ANSI_RESET = "\x1b[0m";

        public inline unowned string to_string () {
            switch (this) {
            case RESET: return ANSI_RESET;
            case RED: return ANSI_RED;
            case GREEN: return ANSI_GREEN;
            case YELLOW: return ANSI_YELLOW;
            case BLUE: return ANSI_BLUE;
            case MAGENTA: return ANSI_MAGENTA;
            case CYAN: return ANSI_CYAN;
            case WHITE: return ANSI_WHITE;
            case BOLD: return ANSI_BOLD;
            case UNDERLINE: return ANSI_UNDERLINE;
            case BLINK: return ANSI_BLINK;
            case DIM: return ANSI_DIM;
            case HIDDEN: return ANSI_HIDDEN;
            case INVERT: return ANSI_INVERT;
            default: return ANSI_RESET;
            }
        }
    }

    /**
     * Reports a failed command with its status.
     *
     * @param command The command that failed.
     * @param status The status code of the failed command.
    */
    public static inline void report_failed_command (string command, int status) {
        if (color_setting.to_bool ()) {
            stderr.printf ("Command `%s%s%s' failed with status: %s%d%s\n",
                Reporter.EscapeCode.ANSI_BOLD + EscapeCode.ANSI_YELLOW,
                command,
                Reporter.EscapeCode.ANSI_RESET,
                Reporter.EscapeCode.ANSI_RED + EscapeCode.ANSI_BOLD,
                status,
                Reporter.EscapeCode.ANSI_RESET);
            return;
        }
        stderr.printf ("Command `%s' failed with status: %d\n",
            command,
            status);
    }

    /**
     * Reports a message with optional color code and domain name.
     *
     * @param color_code The color code to apply to the message. Can be null.
     * @param domain_name The domain name associated with the message.
     * @param msg The message to report.
     * @param args The arguments to format the message.
    */
    public static inline void report (string color_code, string domain_name, string msg, va_list args) {
        if (color_setting.to_bool ()) {
            stderr.puts (Reporter.EscapeCode.ANSI_BOLD.concat (
                    color_code,
                    domain_name,
                    Reporter.EscapeCode.ANSI_RESET +
                    ": " +
                    Reporter.EscapeCode.ANSI_BOLD,
                    msg.vprintf (args),
                    Reporter.EscapeCode.ANSI_RESET +
                    "\n"));
            return;
        }
        stderr.puts (domain_name.concat (": ", msg.vprintf (args), "\n"));
    }

    /**
     * Reports an error with the specified error name and message.
     *
     * @param error_name The name of the error.
     * @param msg The error message.
     * @param ... Additional arguments for the error message.
    */
    [PrintfFormat]
    public static void error (string error_name, string msg, ...) {
        report (Reporter.EscapeCode.ANSI_RED, error_name, msg, va_list ());
    }

    /**
     * Prints a warning message with the specified warning name and message.
     *
     * @param warning_name The name of the warning.
     * @param msg The warning message.
     * @param ... Additional arguments for the message format.
    */
    [PrintfFormat]
    public static void warning (string warning_name, string msg, ...) {
        report (Reporter.EscapeCode.ANSI_MAGENTA, warning_name, msg, va_list ());
    }

    /**
     * Print an informational message.
     *
     * @param info_name The name of the information.
     * @param msg The message to be printed.
     * @param ... Additional arguments to be formatted.
    */
    [PrintfFormat]
    public static void info (string info_name, string msg, ...) {
        report (Reporter.EscapeCode.ANSI_CYAN, info_name, msg, va_list ());
    }

    /**
     * Clears the standard error output and prints a message.
     *
     * @param msg The message to be printed.
     * @param show_progress_bar Whether to show a progress bar or not. Default is true.
    */
    public static void clear_putserr (string msg, bool show_progress_bar = true) {
        if (show_progress_bar) {
            stderr.printf ("\r%s\r%s",
                string.nfill (get_console_width (), ' '),
                msg);
        } else {
            stderr.puts (msg);
        }
    }
}

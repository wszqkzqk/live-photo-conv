/* reporter.vala
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

/**
 * @namespace MotionPhotoConv.Reporter
 * @brief Contains classes and functions for reporting information and errors.
 *
 * The `Reporter` namespace provides functionality for reporting information, errors, and warnings during the execution of the MotionPhotoConv application.
 * It includes classes and functions for printing messages to the standard error stream, formatting messages with color codes, and handling console width.
 *
 * The namespace includes the following classes and enums:
 * - `ColorStats`: An enum representing the color statistics for the console output.
 * - `ColorSettings`: An enum representing the color settings for the console output.
 * - `EscapeCode`: An enum representing the escape codes for formatting console output.
 *
 * The namespace also includes the following functions:
 * - `isatty(int fd)`: A function that checks if the given file descriptor refers to a terminal.
 * - `get_console_width()`: A function that returns the width of the console.
 * - `report_failed_command(string command, int status)`: A function that reports a failed command with the given command and status.
 * - `report(string color_code, string domain_name, string msg, va_list args)`: A function that reports a message with the given color code, domain name, message, and variable arguments.
 * - `error(string error_name, string msg, ...)`: A function that reports an error message with the given error name and message.
 * - `warning(string warning_name, string msg, ...)`: A function that reports a warning message with the given warning name and message.
 * - `info(string info_name, string msg, ...)`: A function that reports an information message with the given info name and message.
 * - `clear_putserr(string msg, bool show_progress_bar = true)`: A function that clears the standard error stream and prints the given message, optionally showing a progress bar.
 */
namespace MotionPhotoConv.Reporter {

    internal static ColorStats color_stats = ColorStats.UNKNOWN;
    public static ColorSettings color_setting = ColorSettings.AUTO;

    [CCode (cheader_filename = "bindings.h", cname = "is_a_tty")]
    public extern static bool isatty (int fd);
    [CCode (cheader_filename = "bindings.h", cname = "get_console_width")]
    public extern static int get_console_width ();

    [CCode (has_type_id = false)]
    internal enum ColorStats {
        NO,
        YES,
        UNKNOWN;

        internal inline bool to_bool () {
            switch (this) {
            case YES: return true;
            case NO: return false;
            default: return Log.writer_supports_color (stderr.fileno ());
            }
        }
    }

    [CCode (has_type_id = false)]
    public enum ColorSettings {
        NEVER,
        ALWAYS,
        AUTO;

        internal inline ColorStats to_color_stats () {
            switch (this) {
            case ALWAYS: return ColorStats.YES;
            case NEVER: return ColorStats.NO;
            default: return Log.writer_supports_color (stderr.fileno ()) ? ColorStats.YES : ColorStats.NO;
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
        if (unlikely (color_stats == ColorStats.UNKNOWN)) {
            color_stats = color_setting.to_color_stats ();
        }
        if (color_stats.to_bool ()) {
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
        if (unlikely (color_stats == ColorStats.UNKNOWN)) {
            color_stats = color_setting.to_color_stats ();
        }
        if (color_stats.to_bool ()) {
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
        if (unlikely (color_stats == ColorStats.UNKNOWN)) {
            color_stats = color_setting.to_color_stats ();
        }
        if (show_progress_bar) {
            stderr.printf ("\r%s\r%s",
                string.nfill (get_console_width (), ' '),
                msg);
        } else {
            stderr.puts (msg);
        }
    }
}

/**
 * @class MotionPhotoConv.ProgressBar
 *
 * ProgressBar is a class that provides a set of functions to show progress bar.
 */
[Compact (opaque = true)]
public class MotionPhotoConv.ProgressBar {

    string title;
    double percentage = 0.0;
    int total_steps;
    int current_step = 0;
    char fill_char;
    char empty_char;

    /**
     * @class ProgressBar
     *
     * Represents a progress bar used for tracking progress of a task.
     *
     * @param total_steps The total number of steps in the progress bar.
     * @param title The title of the progress bar. Default value is "Progress".
     * @param fill_char The character used to represent filled progress. Default value is '#'.
     * @param empty_char The character used to represent empty progress. Default value is '-'.
     */
    public ProgressBar (int total_steps,
                        string title = "Progress",
                        char fill_char = '#',
                        char empty_char = '-') {
        this.title = title;
        this.total_steps = total_steps;
        this.fill_char = fill_char;
        this.empty_char = empty_char;
    }

    /**
     * Updates the progress of the reporter.
     *
     * This method updates the progress of the reporter by incrementing the current step count and calculating the percentage of completion.
     * It also prints the progress and returns the updated current step count.
     *
     * @param success_count The number of successful updates.
     * @param failure_count The number of failed updates.
     *
     * @return The updated current step count.
     */
    public inline int update (uint success_count, uint failure_count) {
        current_step += 1;
        current_step = (current_step > total_steps) ? total_steps : current_step;
        percentage = (double) current_step / total_steps * 100.0;
        print_progress (success_count, failure_count);
        return current_step;
    }

    /**
     * Prints the progress of the operation.
     *
     * @param success_count The number of successful operations.
     * @param failure_count The number of failed operations.
     */
    public inline void print_progress (uint success_count, uint failure_count) {
        // The actual length of the prefix is the length of UNCOLORED prefix
        // ANSI escapecode should not be counted
        var prefix = "\rSuccess: %u Failure: %u ".printf (success_count, failure_count);
        var prelength = prefix.length - 1; // -1 for \r
        if (unlikely (Reporter.color_stats == Reporter.ColorStats.UNKNOWN)) {
            Reporter.color_stats = Reporter.color_setting.to_color_stats ();
        }
        if (Reporter.color_stats.to_bool ()) {
            // Optimized for string literal concatenation:
            // Use `+` to concatenate string literals
            // so that the compiler can optimize it to a single string literal at compile time
            // But still use `concat` to concatenate non-literal strings, use `,` to split args
            prefix = "\r".concat (
                Reporter.EscapeCode.ANSI_BOLD +
                Reporter.EscapeCode.ANSI_GREEN +
                "Success: ",
                success_count.to_string (),
                Reporter.EscapeCode.ANSI_RESET +
                " " +
                Reporter.EscapeCode.ANSI_BOLD +
                Reporter.EscapeCode.ANSI_RED +
                "Failure: ",
                failure_count.to_string (),
                Reporter.EscapeCode.ANSI_RESET +
                " ");
        }
        var builder = new StringBuilder (prefix);
        builder.append (title);
        // 12 is the length of ": [] 100.00%"
        int bar_length = Reporter.get_console_width () - prelength - title.length - 12;
        // Only the the effictive length of progressbar is no less than 5, the progressbar will be shown
        if (Reporter.color_stats.to_bool () && bar_length >= 5) {
            builder.append (": [");
            var fill_length = (int) (percentage / 100.0 * bar_length);
            builder.append (Reporter.EscapeCode.ANSI_INVERT);
            builder.append (string.nfill (fill_length, fill_char));
            builder.append (Reporter.EscapeCode.ANSI_RESET);
            builder.append (string.nfill (bar_length - fill_length, empty_char));
            builder.append_printf ("] %6.2f%%", percentage);
        } else {
            builder.append_printf (": %6.2f%%", percentage);
        }
        stderr.puts (builder.str);
    }
}

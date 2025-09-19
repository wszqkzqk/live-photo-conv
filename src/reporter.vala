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
 * The Reporter class provides methods to report failed commands, general messages,
 * errors, and warnings. It supports color-coded output based on the terminal's capabilities.
*/
[Compact (opaque = true)]
public class LivePhotoConv.Reporter {

    public static ColorSettings color_setting = ColorSettings.AUTO;

    [CCode (cname = "is_a_tty")]
    public extern static bool isatty (int fd);
    [CCode (cname = "get_console_width")]
    public extern static int get_console_width ();

    [CCode (has_type_id = false)]
    public enum ColorSettings {
        NEVER,
        ALWAYS,
        AUTO;

        public bool to_bool () {
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

        public unowned string to_string () {
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
    public static void report_failed_command (string command, int status) {
        if (color_setting.to_bool ()) {
            printerr ("Command `%s%s%s' failed with status: %s%d%s\n",
                Reporter.EscapeCode.ANSI_BOLD + EscapeCode.ANSI_YELLOW,
                command,
                Reporter.EscapeCode.ANSI_RESET,
                Reporter.EscapeCode.ANSI_RED + EscapeCode.ANSI_BOLD,
                status,
                Reporter.EscapeCode.ANSI_RESET);
            return;
        }
        printerr ("Command `%s' failed with status: %d\n",
            command,
            status);
    }

    /**
     * Reports a message with optional color code and domain name. (with printf-style arguments)
     *
     * @param color_code The color code to apply to the message. Can be null.
     * @param domain_name The domain name associated with the message.
     * @param msg The message to report.
     * @param args The arguments to format the message.
    */
    public static void report (string color_code, string domain_name, string msg, va_list args) {
        if (color_setting.to_bool ()) {
            printerr ("%s", Reporter.EscapeCode.ANSI_BOLD.concat (
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
        printerr ("%s: %s\n", domain_name, msg.vprintf (args));
    }

    /*
     * Reports a message with optional color code and domain name. (no printf-style arguments)
     *
     * @param color_code The color code to apply to the message. Can be null.
     * @param domain_name The domain name associated with the message.
     * @param msg The message to report.
     */
    public static void report_puts (string color_code, string domain_name, string msg) {
        if (color_setting.to_bool ()) {
            printerr ("%s", Reporter.EscapeCode.ANSI_BOLD.concat (
                    color_code,
                    domain_name,
                    Reporter.EscapeCode.ANSI_RESET +
                    ": " +
                    Reporter.EscapeCode.ANSI_BOLD,
                    msg,
                    Reporter.EscapeCode.ANSI_RESET +
                    "\n"));
            return;
        }
        printerr ("%s: %s\n", domain_name, msg);
    }

    /**
     * Reports an error with the specified error name and message. (with printf-style arguments)
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
     * Reports an error with the specified error name and message. (no printf-style arguments)
     *
     * @param error_name The name of the error.
     * @param msg The error message.
     * @param ... Additional arguments for the error message.
    */
    public static void error_puts (string error_name, string msg) {
        report_puts (Reporter.EscapeCode.ANSI_RED, error_name, msg);
    }

    /**
     * Prints a warning message with the specified warning name and message. (with printf-style arguments)
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
     * Prints a warning message with the specified warning name and message. (no printf-style arguments)
     *
     * @param warning_name The name of the warning.
     * @param msg The warning message.
     * @param ... Additional arguments for the message format.
    */
    public static void warning_puts (string warning_name, string msg) {
        report_puts (Reporter.EscapeCode.ANSI_MAGENTA, warning_name, msg);
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
     * Print an informational message. (no printf-style arguments)
     *
     * @param info_name The name of the information.
     * @param msg The message to be printed.
    */
    public static void info_puts (string info_name, string msg) {
        report_puts (Reporter.EscapeCode.ANSI_CYAN, info_name, msg);
    }

    /**
     * Clears the standard error output and prints a message.
     *
     * @param msg The message to be printed.
     * @param show_progress_bar Whether to show a progress bar or not. Default is true.
    */
    public static void clear_putserr (string msg, bool show_progress_bar = true) {
        if (show_progress_bar) {
            printerr ("\r%s\r%s",
                string.nfill (get_console_width (), ' '),
                msg);
        } else {
            printerr ("%s", msg);
        }
    }

    /**
     * The ProgressBar class provides a simple implementation of a progress bar that
     * can display the progress of operations in the terminal, including counts of
     * successes and failures.
     */
    [Compact (opaque = true)]
    public class ProgressBar {

        string title;
        char fill_char = '#';
        char empty_char = '-';
        Mutex mutex;
        int _total_steps = 0;
        int _current_step = 0;

        /**
         * The total number of steps for the progress bar.
         */
        public int total_steps {
            get {
                mutex.lock ();
                var result = _total_steps;
                mutex.unlock ();
                return result;
            }
            set {
                mutex.lock ();
                _total_steps = value;
                mutex.unlock ();
            }
        }

        /**
         * The current step number of the progress bar.
         */
        public int current_step {
            get {
                mutex.lock ();
                var result = _current_step;
                mutex.unlock ();
                return result;
            }
            set {
                mutex.lock ();
                _current_step = value;
                mutex.unlock ();
            }
        }

        /**
         * Constructs a ProgressBar object.
         *
         * @param total_steps The total number of steps.
         * @param title The title of the progress bar, defaults to "Progress".
         * @param fill_char The character for the completed portion, defaults to '#'.
         * @param empty_char The character for the incomplete portion, defaults to '-'.
         */
        public ProgressBar (int total_steps,
                            string title = "Progress",
                            char fill_char = '#',
                            char empty_char = '-') {
            this.title = title;
            this._total_steps = total_steps;
            this.fill_char = fill_char;
            this.empty_char = empty_char;
            this.mutex = Mutex ();
        }

        /**
         * Updates the progress bar state.
         *
         * @param success_count The number of successes.
         * @param failure_count The number of failures.
         * @return The current step number.
         */
        public int update (uint success_count, uint failure_count) {
            mutex.lock ();
            _current_step += 1;
            _current_step = (_current_step > _total_steps) ? _total_steps : _current_step;
            print_progress (success_count, failure_count);
            var current = _current_step;
            mutex.unlock ();
            return current;
        }

        /**
         * Prints the current progress bar to the standard error output.
         *
         * @param success_count The number of successes.
         * @param failure_count The number of failures.
         */
        public void print_progress (uint success_count, uint failure_count) {
            mutex.lock ();
            var current = _current_step;
            var total = _total_steps;
            mutex.unlock ();

            if (total == 0) {
                return;
            }
            var percentage = (double) current / total * 100.0;

            // The actual length of the prefix is the length of UNCOLORED prefix
            // ANSI escapecode should not be counted
            var prefix = "\rSuccess: %u Failure: %u ".printf (success_count, failure_count);
            var prelength = prefix.length - 1; // -1 for \r
            if (Reporter.color_setting.to_bool ()) {
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
            if (Reporter.color_setting.to_bool () && bar_length >= 5) {
                builder.append (": [");
                var fill_length = (int) (percentage / 100.0 * bar_length);
                builder.append (Reporter.EscapeCode.ANSI_INVERT);
                builder.append (string.nfill (fill_length, fill_char));
                builder.append (Reporter.EscapeCode.ANSI_RESET);
                builder.append (string.nfill (bar_length - fill_length, empty_char));
                builder.append_printf ("] %6.2f%%", percentage);
            } else if (isatty (stderr.fileno ()) && bar_length >= 5) {
                builder.append (": [");
                var fill_length = (int) (percentage / 100.0 * bar_length);
                builder.append (string.nfill (fill_length, fill_char));
                builder.append (string.nfill (bar_length - fill_length, empty_char));
                builder.append_printf ("] %6.2f%%", percentage);
            } else {
                builder.append_printf (": %6.2f%%", percentage);
            }
            printerr ("%s", builder.str);
        }
    }
}

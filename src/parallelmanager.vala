/* parallelmanager.vala
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

public class Varallel.ParallelManager {
    /* ParallelManager is a class to manage parallel execution of commands. */

    ThreadPool<Unit> pool;
    string original_command;
    GenericArray<GenericArray<string>> original_args;
    int jobs = 0;
    string? shell = null;
    string shell_args = "-c";
    static Regex slot_in_command = null;
    ProgressBar progress_bar = null;
    public bool show_progress_bar = false;
    Mutex mutex = Mutex ();
    bool hide_sub_output = false;
    uint success_count = 0;
    uint failure_count = 0;
    
    public ParallelManager (string original_command,
                            GenericArray<GenericArray<string>> original_args,
                            int jobs = 0,
                            string? shell = null,
                            bool use_shell = true,
                            bool hide_sub_output = false,
                            bool show_progress_bar = false) {
        /**
        * ParallelManager:
        * @original_command: the command to be executed
        * @original_args: the arguments of the command
        * @jobs: the number of jobs to be executed in parallel
        * @shell: the shell to be used
        * @use_shell: whether to use shell
        * @hide_sub_output: whether to hide the output of the subprocesses
        *
        * Create a new ParallelManager instance.
        */
        if (slot_in_command == null) {
            try {
                slot_in_command = new Regex (
                    """\{([0-9]*)(\/|\.|\/\.|\/\/|#)?\}""", 
                    RegexCompileFlags.OPTIMIZE);
            } catch {
                assert_not_reached ();
            }
        }
        this.original_args = original_args;
        this.original_command = original_command;
        // if jobs is 0, use the number of processors
        this.jobs = (jobs == 0) ? (int) get_num_processors () : jobs;
        this.show_progress_bar = show_progress_bar;
        this.hide_sub_output = hide_sub_output;
        if (show_progress_bar) {
            progress_bar = new ProgressBar (original_args.length);
        }
        if (use_shell) {
            choose_shell (shell);
        }
    }

    public void run () throws ThreadError {
        /**
        * run:
        *
        * Run the commands in parallel.
        */
        pool = new ThreadPool<Unit>.with_owned_data (
            (subprsc) => {
                try {
                    var status = subprsc.run ();

                    mutex.lock ();
                    if (!hide_sub_output) {
                        if ((subprsc.error != null && subprsc.error != "")
                        || (subprsc.output != null && subprsc.output != "")) {
                            Reporter.clear_putserr (subprsc.error, show_progress_bar);
                            stdout.puts (subprsc.output);
                        }
                    }
                    if (status == 0) {
                        success_count += 1;
                    } else {
                        failure_count += 1;
                        Reporter.report_failed_command (subprsc.command_line, status);
                    }
                    if (progress_bar != null) {
                        progress_bar.update (success_count, failure_count);
                    }
                    mutex.unlock ();
                } catch (SpawnError e) {
                    mutex.lock ();
                    Reporter.error ("SpawnError", e.message);
                    failure_count += 1;
                    if (progress_bar != null) {
                        progress_bar.update (success_count, failure_count);
                    }
                    mutex.unlock ();
                }
            },
            this.jobs, 
            false);

        if (show_progress_bar) {
            // The initial progress bar (Success: 0 Failure: 0)
            progress_bar.print_progress (success_count, failure_count);
        }
        for (uint i = 0; i < original_args.length; i += 1) {
            var command = parse_single_command (original_command, original_args[i], i);
            if (command == null) {
                mutex.lock ();
                Reporter.error ("ParseError", "Failed to process command `%s'", original_command);
                failure_count += 1;
                if (progress_bar != null) {
                    progress_bar.update (success_count, failure_count);
                }
                mutex.unlock ();
                continue;
            }
            try {
                pool.add (new Unit (command, shell, shell_args));
            } catch (ThreadError e) {
                mutex.lock ();
                Reporter.error ("ThreadError", e.message);
                failure_count += 1;
                if (progress_bar != null) {
                    progress_bar.update (success_count, failure_count);
                }
                mutex.unlock ();
            } catch (ShellError e) {
                mutex.lock ();
                Reporter.error ("ShellError", e.message);
                failure_count += 1;
                if (progress_bar != null) {
                    progress_bar.update (success_count, failure_count);
                }
                mutex.unlock ();
                continue;
            }
        }
    }
    
    public inline void print_commands () {
        /**
        * print_commands:
        * 
        * Print the commands to be executed.
        */
        for (uint i = 0; i < original_args.length; i += 1) {
            var command = parse_single_command (original_command, original_args[i], i);
            if (command == null) {
                Reporter.error ("ParseError", "Failed to process command `%s'", original_command);
                continue;
            }
            stdout.printf ("%s\n", command);
        }
    }

    static inline string? parse_single_command (string command, GenericArray<string> single_arg_list, uint index) {
        /**
        * parse_single_command:
        * @command: the command to be executed
        * @single_arg: the argument of the command
        * @index: the index of the job
        *
        * Process a single command.
        */
        try {
            var ret = slot_in_command.replace_eval (
                command,
                -1,
                0,
                0,
                (match_info, builder) => {
                    var position_str = match_info.fetch (1);
                    var indicator = match_info.fetch (2);
                    // position == 0 means using all args in single_arg_list
                    // position > 0 means using single_arg_list[position]
                    int position = 0;
                    unowned string single_arg = null;

                    if (position_str != null) {
                        position = int.parse (position_str);
                    }
                    if (position > single_arg_list.length) {
                        // The position is out of range
                        // Feature: If the position is out of range,
                        // directly return (means to replace it with "")
                        // equal to remove the slot (instead of ignore)
                        return false;
                    } else if (position > 0) {
                        single_arg = single_arg_list[position - 1];
                    }

                    if (indicator == null) {
                        // {}: Input argument
                        if (position == 0) {
                            builder.append (string.joinv (" ", single_arg_list.data));
                        } else {
                            builder.append (single_arg);
                        }
                        return false;
                    }

                    switch (indicator.length) {
                    case 0:
                        // {}: Input argument
                        if (position == 0) {
                            builder.append (string.joinv (" ", single_arg_list.data));
                        } else {
                            builder.append (single_arg);
                        }
                        return false;
                    case 1:
                        switch (indicator[0]) {
                        case '#':
                            // {#}: Job index
                            // The job index is 1-based, so we need to add 1
                            builder.append ((index + 1).to_string ());
                            return false;
                        case '/':
                            // {/}: Basename of input line
                            if (position == 0) {
                                for (uint i = 0; i < single_arg_list.length; i += 1) {
                                    if (i != 0) {
                                        builder.append_c (' ');
                                    }
                                    builder.append (Path.get_basename (single_arg_list[i]));
                                }
                            } else {
                                builder.append (Path.get_basename (single_arg));
                            }
                            return false;
                        case '.':
                            // {.}: Input argument without extension
                            if (position == 0) {
                                for (uint i = 0; i < single_arg_list.length; i += 1) {
                                    if (i != 0) {
                                        builder.append_c (' ');
                                    }
                                    builder.append (get_name_without_extension (single_arg_list[i]));
                                }
                            } else {
                                builder.append (get_name_without_extension (single_arg));
                            }
                            return false;
                        default:
                            break;
                        }
                        break;
                    case 2:
                        // May be {//} or {/.}
                        switch (indicator[1]) {
                        case '/':
                            // {//}: Dirname of input line
                            if (position == 0) {
                                for (uint i = 0; i < single_arg_list.length; i += 1) {
                                    if (i != 0) {
                                        builder.append_c (' ');
                                    }
                                    builder.append (Path.get_dirname (single_arg_list[i]));
                                }
                            } else {
                                builder.append (Path.get_dirname (single_arg));
                            }
                            return false;
                        case '.':
                            // {/.}: Basename without extension of input line
                            if (position == 0) {
                                for (uint i = 0; i < single_arg_list.length; i += 1) {
                                    if (i != 0) {
                                        builder.append_c (' ');
                                    }
                                    builder.append (
                                        get_name_without_extension (Path.get_basename (single_arg_list[i]))
                                    );
                                }
                            } else {
                                builder.append (
                                    get_name_without_extension (Path.get_basename (single_arg))
                                );
                            }
                            return false;
                        default:
                            break;
                        }
                        break;
                    default:
                        break;
                    }
                    Reporter.warning ("Warning", "Unknown slot: {%s}", indicator);
                    if (position == 0) {
                        builder.append (string.joinv (" ", single_arg_list.data));
                    } else {
                        builder.append (single_arg);
                    }
                    return false;
                }
            );
            // Consider the case that the command is not changed
            // Put the argument at the end of the command
            if (ret == command) {
                ret = "%s %s".printf (
                    command, 
                    string.joinv (" ", single_arg_list.data));
            }
            return ret;
        } catch (RegexError e) {
            Reporter.error ("RegexError", e.message);
            return null;
        }
    }

    inline static string get_name_without_extension (string filename) {
        /**
        * get_name_without_extension:
        * @filename: the filename
        *
        * Get the name of the file without extension.
        */
        var last_dot = filename.last_index_of_char ('.');
        var last_separator = filename.last_index_of_char (Path.DIR_SEPARATOR);
#if WINDOWS
        {
            // Windows can also use / as the separator
            var last_slash = filename.last_index_of_char ('/');
            if (last_slash > last_separator) {
                last_separator = last_slash;
            }
        }
#endif
        if (last_dot == -1 || last_dot < last_separator) {
            return filename;
        } else {
            return filename[:last_dot];
        }
    }

    inline void choose_shell (string? shell) {
        if (shell != null) {
            // if shell is not null, use it
#if WINDOWS
            this.shell = shell.ascii_down ();
            // if the shell is cmd or cmd.exe, use /c as the shell_args
            if (this.shell.has_suffix ("cmd") || this.shell.has_suffix ("cmd.exe")) {
                this.shell_args = "/c";
            }
#else
            this.shell = shell;
#endif
        } else {
#if !WINDOWS
            // if shell is null and the system is not windows, use the SHELL environment variable
            this.shell = Environment.get_variable("SHELL");
            // if the SHELL environment variable is not set, use /bin/sh
            if (this.shell == null) {
                this.shell = Environment.find_program_in_path ("sh");
            }
            // if the system is windows, directly spawn the command
#endif
        }
    }
}

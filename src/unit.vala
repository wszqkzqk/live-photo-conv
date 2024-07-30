/* unit.vala
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
public class Varallel.Unit {
    /* Unit is a class that represents a subprocess to be executed. */

    string[] commands;
    string subprcs_output;
    string subprcs_error;
    int subprcs_status;

    public unowned string command_line {
        get {
            return commands[2];
        }
    }
    public unowned string? output {
        get {
            return subprcs_output;
        }
    }
    public unowned string? error {
        get {
            return subprcs_error;
        }
    }
    public int status {
        get {
            return subprcs_status;
        }
    }

    public Unit (string command_line, string? shell, string? exec_arg) throws ShellError {
        if (shell == null) {
            // If shell is not specified, do not use shell and just execute the command directly
            Shell.parse_argv (command_line, out commands);
        } else {
            commands = {shell, exec_arg, command_line};
        }
    }

    public int run () throws SpawnError {
        Process.spawn_sync (
            null,
            commands,
            null,
            SpawnFlags.SEARCH_PATH,
            null,
            out subprcs_output,
            out subprcs_error,
            out subprcs_status);
        return subprcs_status;
    }
}

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

#pragma once

#include <glib.h>

#if defined(_WIN32) // Windows
#include <windows.h>
#include <io.h>

#else // Unix
#include <sys/ioctl.h>
#include <unistd.h>
#endif

#define get_console_width() get_console_width_inline()
#define is_a_tty(fd) is_a_tty_inline(fd)

G_ALWAYS_INLINE
static inline int get_console_width_inline () {
#if defined(_WIN32)
    CONSOLE_SCREEN_BUFFER_INFO csbi;
    int columns;
    // GetConsoleScreenBufferInfo will return 0 if it FAILS
    int success = GetConsoleScreenBufferInfo (GetStdHandle (STD_ERROR_HANDLE), &csbi);
    if (success) {
        columns = csbi.srWindow.Right - csbi.srWindow.Left + 1;
        return (int) columns;
    } else {
        return 0;
    }
#else // Unix
    struct winsize w;
    // ioctl will return 0 if it SUCCEEDS
    int fail  = ioctl (STDERR_FILENO, TIOCGWINSZ, &w);
    if (fail) {
        return 0;
    } else {
        return (int) w.ws_col;
    }
#endif
}

G_ALWAYS_INLINE
static inline gboolean is_a_tty_inline (int fd) {
#if defined(_WIN32)
    return (gboolean) (_isatty (fd) != 0);
#else // Unix
    return (gboolean) (isatty (fd) != 0);
#endif
}

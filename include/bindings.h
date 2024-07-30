/* bindings.h
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

#if !defined(VALA_EXTERN)
#if defined(_WIN32) || defined(__CYGWIN__)
#define VALA_EXTERN __declspec(dllexport) extern
#elif __GNUC__ >= 4
#define VALA_EXTERN __attribute__((visibility("default"))) extern
#else
#define VALA_EXTERN extern
#endif
#endif

#include <glib.h>

#if defined(_WIN32)
#include <windows.h>
#include <io.h>

static inline int get_console_width () {
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
}

static inline gboolean is_a_tty (int fd) {
    return (gboolean) (_isatty (fd) != 0);
}
#else
#include <sys/ioctl.h>
#include <unistd.h>

static inline int get_console_width () {
    struct winsize w;
    // ioctl will return 0 if it SUCCEEDS
    int fail  = ioctl (STDERR_FILENO, TIOCGWINSZ, &w);
    if (fail) {
        return 0;
    } else {
        return (int) w.ws_col;
    }
}

static inline gboolean is_a_tty (int fd) {
    return (gboolean) (isatty (fd) != 0);
}
#endif

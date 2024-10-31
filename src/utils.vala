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

namespace LivePhotoConv.Utils {
    const int BUFFER_SIZE = 1 << 14; // 2^4 * 2^10 B = 16 KiB

    /**
     * Reads a string from an input stream.
     *
     * This function reads data from the provided input stream and converts it into a string.
     * It uses a buffer to read the data in chunks and appends it to a string builder.
     * The function continues reading until there is no more data to read from the input stream.
     *
     * @param input_stream The input stream to read from.
     * @throws IOError if an error occurs while reading from the input stream.
     * @return The string read from the input stream.
    */
    public string get_string_from_file_input_stream (InputStream input_stream) throws IOError {
        StringBuilder? builder = null;
        uint8[] buffer = new uint8[BUFFER_SIZE + 1]; // allocate one more byte for the null terminator
        buffer.length = BUFFER_SIZE; // Set the length of the buffer to BUFFER_SIZE
        ssize_t bytes_read;

        while ((bytes_read = input_stream.read (buffer)) > 0) {
            buffer[bytes_read] = '\0'; // Add a null terminator to the end of the string
            if (builder == null) {
                builder = new StringBuilder.from_buffer ((char[]) buffer);
            } else {
                (!) builder.append ((string) buffer);
            }
        }

        return (builder != null) ? (!) builder.free_and_steal () : "";
    }

    /**
     * Writes the contents of an input stream to an output stream.
     *
     * @param input_stream The input stream to read from.
     * @param output_stream The output stream to write to.
     *
     * @throws IOError if an error occurs while reading from or writing to the streams.
    */
    public void write_stream (InputStream input_stream, OutputStream output_stream) throws IOError {
        var buffer = new uint8[BUFFER_SIZE];
        ssize_t bytes_read;
        while ((bytes_read = input_stream.read (buffer)) > 0) {
            buffer.length = (int) bytes_read;
            output_stream.write (buffer);
            buffer.length = BUFFER_SIZE;
        }
    }

    /**
     * Writes data from an input stream to an output stream until a specified end position is reached.
     *
     * @param input_stream The input stream to read data from.
     * @param output_stream The output stream to write data to.
     * @param end The position in the input stream to stop writing data at.
     *
     * @throws IOError if an error occurs while reading from or writing to the streams.
    */
    public void write_stream_before (InputStream input_stream, OutputStream output_stream, int64 end) throws IOError {
        var bytes_to_write = end;
        var buffer = new uint8[BUFFER_SIZE];
        ssize_t bytes_read;
        while ((bytes_read = input_stream.read (buffer)) > 0 && bytes_to_write > 0) {
            if (bytes_read > bytes_to_write) {
                buffer.length = (int) bytes_to_write;
            } else {
                buffer.length = (int) bytes_read;
            }
            output_stream.write (buffer);
            buffer.length = BUFFER_SIZE;
            bytes_to_write -= bytes_read;
        }
    }
}

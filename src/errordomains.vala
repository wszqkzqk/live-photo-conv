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

namespace LivePhotoConv {

    public errordomain NotLivePhotosError {
        OFFSET_NOT_FOUND_ERROR, // The offset of the video data in the live photo is not found.
        INVALID_FILE_FORMAT, // The file format is not a valid live photo.
    }

    public errordomain ExportError {
        FFMPEG_EXIED_WITH_ERROR, // FFmpeg failed to split the video into images.
        METADATA_EXPORT_ERROR, // Failed to export the metadata.
        FILE_PUSH_ERROR, // Failed to push data to file.
        GST_PIPELINE_ERROR, // GStreamer pipeline initialization/creation failed.
        DIRECTORY_CREATE_ERROR, // Failed to create directory.
        FILE_WRITE_ERROR, // Failed to write to file.
        STREAM_READ_ERROR, // Failed to read from stream.
        STREAM_WRITE_ERROR, // Failed to write to stream.
    }

    public errordomain ProcessError {
        COMMAND_EXECUTION_FAILED, // External command execution failed.
        INVALID_PROCESS_OUTPUT, // Process output is invalid or unexpected.
        PROCESS_TIMEOUT, // Process execution timeout.
    }

    public errordomain ValidationError {
        INVALID_PATH, // Invalid file or directory path.
        MISSING_REQUIRED_FILE, // Required file is missing.
        INSUFFICIENT_PERMISSIONS, // Insufficient permissions to access file.
        UNSUPPORTED_FORMAT, // Unsupported file format.
    }
}

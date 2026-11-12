/* Copyright 2024-2026 Zhou Qiankang <wszqkzqk@qq.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
*/

/**
 * Represents an owned, tightly packed RGB video frame.
 *
 * Uses GStreamer's video-frame metadata to copy the active pixels out of
 * the mapped buffer. Rows contain exactly `width * 3` bytes, with no
 * padding, so the frame remains valid after the buffer is unmapped.
 */
internal class LivePhotoConv.PackedRgbFrame : Object {
    public int width {get; private set;}
    public int height {get; private set;}

    /** Packed pixels in row-major order, with `width * 3` bytes per row. */
    public uint8[] data;

    /**
     * Constructor for the PackedRgbFrame class.
     *
     * @param sample The Gst.Sample object to be converted. Its caps must
     * describe 8-bit RGB video.
     * @throws Error if the sample is not RGB, has invalid dimensions, or
     * its buffer cannot be mapped.
    */
    public PackedRgbFrame (Gst.Sample sample) throws Error {
        var info = new Gst.Video.Info ();
        if (!info.from_caps (sample.get_caps ())
            || info.finfo == null || info.finfo.format != Gst.Video.Format.RGB) {
            throw new ExportError.GST_ERROR ("Expected an RGB video sample");
        }
        if (info.width <= 0 || info.height <= 0) {
            throw new ExportError.GST_ERROR ("Invalid video frame dimensions");
        }

        int64 row_size = (int64) info.width * 3;
        if (row_size > int.MAX / info.height) {
            throw new ExportError.GST_ERROR ("Video frame is too large to address");
        }
        int64 packed_size = row_size * info.height;

        Gst.Video.Frame frame = Gst.Video.Frame ();
        if (!frame.map (info, sample.get_buffer (), Gst.MapFlags.READ)) {
            throw new ExportError.GST_ERROR ("Cannot map the video frame buffer");
        }

        try {
            // GstVideoFrame embeds GstVideoInfo inline; the VAPI incorrectly exposes it as a reference.
            Gst.Video.Info* mapped_info = (Gst.Video.Info*) &frame.info;
            int stride = mapped_info->stride[0];
            int64 stride_size = stride < 0 ? -(int64) stride : (int64) stride;
            if (stride_size < row_size) {
                throw new ExportError.GST_ERROR ("Video frame stride is smaller than its pixel data");
            }

            this.width = info.width;
            this.height = info.height;
            int row_bytes = (int) row_size;
            this.data = new uint8[(int) packed_size];
            unowned uint8* plane = (uint8*) frame.data[0];
            for (int y = 0; y < this.height; y++) {
                Memory.copy (&this.data[y * row_bytes], plane + (int64) y * stride, row_bytes);
            }
        } finally {
            frame.unmap ();
        }
    }

    /**
     * Converts the frame to a pixbuf.
     *
     * This method transfers ownership of the packed pixel data to the
     * returned pixbuf; the frame's data must no longer be used afterwards.
     *
     * @return A new RGB pixbuf that owns the converted pixel storage.
    */
    public Gdk.Pixbuf to_pixbuf () {
        uint8[] pixels = (owned) this.data;
        return new Gdk.Pixbuf.from_data (
            (owned) pixels,
            Gdk.Colorspace.RGB,
            false,
            8,
            this.width,
            this.height,
            this.width * 3
        );
    }
}

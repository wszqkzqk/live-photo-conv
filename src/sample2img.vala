/* Copyright 2024-2026 Zhou Qiankang <wszqkzqk@qq.com>
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

    /**
     * Returns the pixbuf with an opaque alpha channel, adding one if missing.
     *
     * gdk-pixbuf's Android saver hands the pixel buffer to
     * AndroidBitmap_compress() as RGBA_8888, so saving a pixbuf without
     * an alpha channel always fails with ANDROID_BITMAP_RESULT_BAD_PARAMETER.
     * Pixbufs decoded by gdk-pixbuf's Android loader are already RGBA, and
     * other platforms' savers accept RGB: a no-op in both cases.
     *
     * @param pixbuf The pixbuf to convert.
     * @return The pixbuf with an alpha channel, or the input itself if it already has one.
     */
    internal Gdk.Pixbuf pixbuf_with_opaque_alpha (Gdk.Pixbuf pixbuf) {
#if ANDROID
        return pixbuf.has_alpha ? pixbuf : pixbuf.add_alpha (false, 0, 0, 0);
#else
        return pixbuf;
#endif
    }
}

/**
 * Represents a class for converting a GStreamer sample to an image file.
*/
internal class LivePhotoConv.Sample2Img : Object {

    // GExiv2 handles are not thread-safe
    private static Mutex export_mutex;

    public string output_format {get; set;}
    public string filename {get; set;}
    public Gdk.Pixbuf pixbuf {get; private set;}

    /**
     * Constructor for the Sample2Img class.
     *
     * @param sample The Gst.Sample object to be processed.
     * @param filename The name of the output file.
     * @param output_format The format of the output file.
     * @throws Error if the sample's caps or buffer cannot be read.
    */
    public Sample2Img (Gst.Sample sample, string filename, string output_format) throws Error {
        this.filename = filename;
        this.output_format = output_format;

        unowned var buffer = sample.get_buffer ();
        unowned var caps = sample.get_caps ();
        unowned var info = caps.get_structure (0);
        int width, height;
        info.get_int ("width", out width);
        info.get_int ("height", out height);

        Gst.MapInfo map;
        if (!buffer.map (out map, Gst.MapFlags.READ)) {
            throw new ExportError.GST_ERROR ("Cannot map the video frame buffer");
        }

        // The pixbuf owns a copy of the pixels, so the buffer can be unmapped right away
        pixbuf = new Gdk.Pixbuf.from_data (
            map.data,
            Gdk.Colorspace.RGB,
            false,
            8,
            width,
            height,
            width * 3
        );
        buffer.unmap (map);
        pixbuf = pixbuf_with_opaque_alpha (pixbuf);
    }

    /**
     * Export the sample as an image.
     *
     * @param metadata The metadata to be saved along with the image. (optional)
     * @throws Error if an error occurs during the export process.
    */
    public void export (GExiv2.Metadata? metadata = null) throws Error {
        pixbuf.save (filename, output_format);

        Reporter.info_puts ("Exported image", filename);

        if (metadata != null) {
            export_mutex.lock ();
            try {
                metadata.save_file (filename);
            } catch (Error e) {
                throw new ExportError.METADATA_EXPORT_ERROR ("Cannot save metadata to `%s': %s", filename, e.message);
            } finally {
                export_mutex.unlock ();
            }
        }
    }

    public void save_to_stream (OutputStream stream) throws Error {
        pixbuf.save_to_stream (stream, output_format);
    }
}

/* sample2img.vala
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
 * @class LivePhotoConv.Sample2Img
 *
 * Represents a class for converting a GStreamer sample to an image file.
 */
[Compact (opaque = true)]
public class LivePhotoConv.Sample2Img {
    Gst.Sample sample;
    string filename;
    string output_format;

    /**
     * Constructor for the Sample2Img class.
     *
     * @param sample The Gst.Sample object to be processed.
     * @param filename The name of the output file.
     * @param output_format The format of the output file.
     */
    public Sample2Img (Gst.Sample sample, string filename, string output_format) {
        this.sample = sample;
        this.filename = filename;
        this.output_format = output_format;
    }

    /**
     * Export the sample as an image.
     *
     * @param metadata The metadata to be saved along with the image. (optional)
     * @throws Error if an error occurs during the export process.
     */
    public void export (GExiv2.Metadata? metadata = null) throws Error {
        unowned var buffer = this.sample.get_buffer ();
        unowned var caps = this.sample.get_caps ();
        unowned var info = caps.get_structure (0);
        int width, height;
        info.get_int ("width", out width);
        info.get_int ("height", out height);
        
        Gst.MapInfo map;
        buffer.map (out map, Gst.MapFlags.READ);
        Gdk.Pixbuf pixbuf = new Gdk.Pixbuf.from_data (
            map.data,
            Gdk.Colorspace.RGB,
            false,
            8,
            width,
            height,
            width * 3
        );

        pixbuf.save (filename, output_format);
        Reporter.info ("Exported image", filename);

        if (metadata != null) {
            try {
                metadata.save_file (filename);
            } catch (Error e) {
                throw new ExportError.MATEDATA_EXPORT_ERROR ("Cannot save metadata to `%s': %s", filename, e.message);
            }
        }
    }
}

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
     * Video processing backend.
     *
     * Used by {@link LivePhoto.create} and {@link LiveMaker.create} to pick
     * the concrete implementation. The backend classes themselves are
     * internal; this enum is the only way to express a preference.
     */
    public enum Backend {
        AUTO,
        GST,
        FFMPEG
    }

    static size_t exiv2_once = 0;

    /** Thread-safe one-time exiv2/XMP initialization (GOnce-guarded). */
    internal void ensure_exiv2_init () {
        if (Once.init_enter (&exiv2_once)) {
            GExiv2.initialize ();
            try {
                GExiv2.Metadata.register_xmp_namespace ("http://ns.google.com/photos/1.0/camera/", "GCamera");
                GExiv2.Metadata.register_xmp_namespace ("http://ns.google.com/photos/1.0/container/", "Container");
                GExiv2.Metadata.register_xmp_namespace ("http://ns.google.com/photos/1.0/container/item/", "Item");
            } catch {}
            Once.init_leave (&exiv2_once, 1);
        }
    }
}

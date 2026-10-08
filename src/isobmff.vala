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

internal errordomain LivePhotoConv.IsoBmffError {
    MALFORMED_CONTAINER,
    MULTIPLE_MPVD,
    INVALID_MP4,
}

internal struct LivePhotoConv.MpvdVideoRange {
    public int64 offset;
    public int64 length;
    /** Size of the main image data preceding the mpvd box. */
    public int64 main_image_size;
}

/** Structured, bounded access to the MP4 embedded in an ISO-BMFF mpvd box. */
namespace LivePhotoConv.IsoBmff {
    const uint32 FTYP = 0x66747970;
    const uint32 STYP = 0x73747970;
    const uint32 MOOV = 0x6d6f6f76;
    const uint32 MDAT = 0x6d646174;
    const uint32 META = 0x6d657461;
    const uint32 FREE = 0x66726565;
    const uint32 SKIP = 0x736b6970;
    const uint32 WIDE = 0x77696465;
    const uint32 UUID = 0x75756964;
    const uint32 PDIN = 0x7064696e;
    const uint32 MPVD = 0x6d707664;
    const uint32 SEFD = 0x73656664;
    const uint32 IPRP = 0x69707270;
    const uint32 PITM = 0x7069746d;
    const uint32 IPCO = 0x6970636f;
    const uint32 IPMA = 0x69706d61;
    const uint32 IROT = 0x69726f74;
    const uint32 IMIR = 0x696d6972;

    struct Box {
        int64 offset;
        int64 end;
        int64 payload_offset;
        int64 payload_size;
        uint32 type;
    }

    /**
     * Finds the single top-level mpvd box and validates its embedded MP4.
     *
     * A null result means that the input is not recognizable as ISO-BMFF.
     * An ISO-BMFF file without mpvd, or with a malformed container, raises an
     * error rather than falling back to byte-pattern searches.
     */
    internal MpvdVideoRange? find_mpvd_video (string filename) throws Error {
        var file = File.new_for_commandline_arg (filename);
        var file_size = file.query_info ("standard::size", FileQueryInfoFlags.NONE).get_size ();
        if (file_size < 8)
            return null;

        var input = file.read ();
        uint8[] signature = new uint8[8];
        size_t signature_size;
        input.read_all (signature, out signature_size, null);
        if (signature_size != signature.length)
            return null;
        if ((signature[0] == 0xff && signature[1] == 0xd8)
            || !is_bmff_start (read_be32 (signature, 4))) {
            return null;
        }

        Box? mpvd = null;
        int64 position = 0;
        while (position < file_size) {
            Box box;
            read_box (input, position, file_size, out box);
            if (box.type == MPVD) {
                if (mpvd != null) {
                    throw new IsoBmffError.MULTIPLE_MPVD (
                        "The ISO-BMFF container contains more than one top-level mpvd box");
                }
                mpvd = box;
            }
            position = box.end;
        }

        if (mpvd == null) {
            throw new NotLivePhotosError.OFFSET_NOT_FOUND_ERROR (
                "The ISO-BMFF container does not contain an mpvd video box");
        }
        var range = validate_mpvd (input, mpvd);
        range.main_image_size = mpvd.offset;
        return range;
    }

    /**
     * Returns whether the primary HEIF item has a non-identity display transform.
     *
     * This examines item properties directly and does not require an mpvd box.
     */
    internal bool primary_has_display_transform (string filename) throws Error {
        var file = File.new_for_commandline_arg (filename);
        var file_size = file.query_info ("standard::size", FileQueryInfoFlags.NONE).get_size ();
        if (file_size < 8) {
            throw new IsoBmffError.MALFORMED_CONTAINER (
                "Truncated ISO-BMFF container: no complete top-level box header");
        }

        var input = file.read ();
        Box? meta = null;
        int64 position = 0;
        while (position < file_size) {
            Box box;
            read_box (input, position, file_size, out box);
            if (box.type == META) {
                if (meta != null) {
                    throw new IsoBmffError.MALFORMED_CONTAINER (
                        "The ISO-BMFF container contains more than one top-level meta box");
                }
                meta = box;
            }
            position = box.end;
        }

        if (meta == null) {
            throw new IsoBmffError.MALFORMED_CONTAINER (
                "The HEIF container does not contain a top-level meta box");
        }

        uint8[] meta_header = new uint8[4];
        read_exact (input, meta.payload_offset, meta.end, meta_header, "meta FullBox header");
        if (meta_header[0] != 0) {
            throw new IsoBmffError.MALFORMED_CONTAINER (
                "Unsupported meta box version %u".printf (meta_header[0]));
        }

        Box? iprp = null;
        bool has_pitm = false;
        uint32 primary_item_id = 0;
        position = meta.payload_offset + 4;
        while (position < meta.end) {
            Box box;
            read_box (input, position, meta.end, out box);
            if (box.type == PITM) {
                if (has_pitm) {
                    throw new IsoBmffError.MALFORMED_CONTAINER (
                        "The meta box contains more than one pitm box");
                }
                primary_item_id = read_primary_item_id (input, box);
                has_pitm = true;
            } else if (box.type == IPRP) {
                if (iprp != null) {
                    throw new IsoBmffError.MALFORMED_CONTAINER (
                        "The meta box contains more than one iprp box");
                }
                iprp = box;
            }
            position = box.end;
        }

        if (!has_pitm) {
            throw new IsoBmffError.MALFORMED_CONTAINER (
                "The meta box does not contain a pitm primary item box");
        }
        if (iprp == null) {
            return false;
        }
        return primary_iprp_has_display_transform (input, iprp, primary_item_id);
    }

    uint32 read_primary_item_id (FileInputStream input, Box pitm) throws Error {
        uint8[] header = new uint8[4];
        read_exact (input, pitm.payload_offset, pitm.end, header, "pitm FullBox header");

        if (header[0] == 0) {
            uint8[] item_id_bytes = new uint8[2];
            read_exact (input, pitm.payload_offset + 4, pitm.end, item_id_bytes,
                "pitm primary item ID");
            return read_be16 (item_id_bytes, 0);
        }
        if (header[0] == 1) {
            uint8[] item_id_bytes = new uint8[4];
            read_exact (input, pitm.payload_offset + 4, pitm.end, item_id_bytes,
                "pitm primary item ID");
            return read_be32 (item_id_bytes, 0);
        }
        throw new IsoBmffError.MALFORMED_CONTAINER (
            "Unsupported pitm box version %u".printf (header[0]));
    }

    bool primary_iprp_has_display_transform (FileInputStream input, Box iprp,
                                             uint32 primary_item_id) throws Error {
        Box? ipco = null;
        int64 position = iprp.payload_offset;
        while (position < iprp.end) {
            Box box;
            read_box (input, position, iprp.end, out box);
            if (box.type == IPCO) {
                if (ipco != null) {
                    throw new IsoBmffError.MALFORMED_CONTAINER (
                        "The iprp box contains more than one ipco box");
                }
                ipco = box;
            }
            position = box.end;
        }

        if (ipco == null) {
            throw new IsoBmffError.MALFORMED_CONTAINER (
                "The iprp box does not contain an ipco property container");
        }

        int64 property_count = count_ipco_properties (input, ipco);
        bool has_transform = false;
        position = iprp.payload_offset;
        while (position < iprp.end) {
            Box box;
            read_box (input, position, iprp.end, out box);
            if (box.type == IPMA
                && primary_ipma_has_display_transform (input, box, ipco, property_count,
                    primary_item_id)) {
                has_transform = true;
            }
            position = box.end;
        }
        return has_transform;
    }

    int64 count_ipco_properties (FileInputStream input, Box ipco) throws Error {
        int64 property_count = 0;
        int64 position = ipco.payload_offset;
        while (position < ipco.end) {
            Box property;
            read_box (input, position, ipco.end, out property);
            property_count++;
            position = property.end;
        }
        return property_count;
    }

    bool primary_ipma_has_display_transform (FileInputStream input, Box ipma, Box ipco,
                                             int64 property_count, uint32 primary_item_id) throws Error {
        uint8[] bytes1 = new uint8[1];
        uint8[] bytes2 = new uint8[2];
        uint8[] bytes4 = new uint8[4];
        read_exact (input, ipma.payload_offset, ipma.end, bytes4, "ipma FullBox header");
        uint32 full_box = read_be32 (bytes4, 0);
        uint8 version = (uint8) (full_box >> 24);
        if (version > 1) {
            throw new IsoBmffError.MALFORMED_CONTAINER (
                "Unsupported ipma box version %u".printf (version));
        }
        bool wide_property_indices = (full_box & 1) != 0;

        read_exact (input, ipma.payload_offset + 4, ipma.end, bytes4, "ipma entry count");
        uint32 entry_count = read_be32 (bytes4, 0);
        int64 position = ipma.payload_offset + 8;
        bool has_transform = false;

        for (uint64 entry = 0; entry < (uint64) entry_count; entry++) {
            uint32 item_id;
            if (version == 0) {
                read_exact (input, position, ipma.end, bytes2, "ipma item ID");
                item_id = read_be16 (bytes2, 0);
                position += 2;
            } else {
                read_exact (input, position, ipma.end, bytes4, "ipma item ID");
                item_id = read_be32 (bytes4, 0);
                position += 4;
            }

            read_exact (input, position, ipma.end, bytes1, "ipma association count");
            int association_count = bytes1[0];
            position += 1;
            for (int association = 0; association < association_count; association++) {
                uint32 property_index;
                bool essential_property;
                if (wide_property_indices) {
                    read_exact (input, position, ipma.end, bytes2, "ipma property association");
                    essential_property = (read_be16 (bytes2, 0) & 0x8000) != 0;
                    property_index = (uint32) (read_be16 (bytes2, 0) & 0x7fff);
                    position += 2;
                } else {
                    read_exact (input, position, ipma.end, bytes1, "ipma property association");
                    essential_property = (bytes1[0] & 0x80) != 0;
                    property_index = (uint32) (bytes1[0] & 0x7f);
                    position += 1;
                }

                if (essential_property && property_index == 0) {
                    throw new IsoBmffError.MALFORMED_CONTAINER (
                        "ipma contains an essential association with no property");
                }
                if ((int64) property_index > property_count) {
                    throw new IsoBmffError.MALFORMED_CONTAINER (
                        "ipma property index %u is outside the ipco property array".printf (
                            property_index));
                }
                if (item_id != primary_item_id || property_index == 0) {
                    continue;
                }

                Box property;
                find_ipco_property (input, ipco, property_index, out property);
                if (property.type == IROT) {
                    read_exact (input, property.payload_offset, property.end, bytes1,
                        "irot property payload");
                    if ((bytes1[0] & 0x03) != 0) {
                        has_transform = true;
                    }
                } else if (property.type == IMIR) {
                    read_exact (input, property.payload_offset, property.end, bytes1,
                        "imir property payload");
                    has_transform = true;
                }
            }
        }
        return has_transform;
    }

    void find_ipco_property (FileInputStream input, Box ipco, uint32 property_index,
                             out Box result) throws Error {
        int64 current_index = 1;
        int64 position = ipco.payload_offset;
        while (position < ipco.end) {
            Box property;
            read_box (input, position, ipco.end, out property);
            if (current_index == (int64) property_index) {
                result = property;
                return;
            }
            current_index++;
            position = property.end;
        }
        throw new IsoBmffError.MALFORMED_CONTAINER (
            "ipma property index %u does not identify an ipco property".printf (property_index));
    }

    void read_exact (FileInputStream input, int64 offset, int64 limit,
                     uint8[] data, string description) throws Error {
        if (offset < 0 || limit < offset || (int64) data.length > limit - offset) {
            throw new IsoBmffError.MALFORMED_CONTAINER (
                "%s is truncated or exceeds its enclosing boundary at offset %lld".printf (
                    description, offset));
        }

        input.seek (offset, SeekType.SET);
        size_t bytes_read;
        input.read_all (data, out bytes_read, null);
        if (bytes_read != data.length) {
            throw new IsoBmffError.MALFORMED_CONTAINER (
                "Truncated %s at offset %lld".printf (description, offset));
        }
    }

    uint16 read_be16 (uint8[] data, int offset) {
        return ((uint16) data[offset] << 8) | (uint16) data[offset + 1];
    }

    bool is_bmff_start (uint32 type) {
        return type == FTYP || type == STYP || type == MOOV || type == MDAT
            || type == META || type == FREE || type == SKIP || type == WIDE
            || type == UUID || type == PDIN || type == MPVD;
    }

    MpvdVideoRange validate_mpvd (FileInputStream input, Box mpvd) throws Error {
        int64 payload_end = mpvd.end;
        if (mpvd.payload_offset == payload_end) {
            throw new IsoBmffError.INVALID_MP4 ("The mpvd box has an empty payload");
        }

        bool has_moov = false;
        bool has_mdat = false;
        int64 video_end = payload_end;
        int64 position = mpvd.payload_offset;
        Box box;
        while (position < payload_end) {
            read_box (input, position, payload_end, out box);
            if (position == mpvd.payload_offset && (box.type != FTYP || box.payload_size < 8)) {
                throw new IsoBmffError.INVALID_MP4 (
                    "The mpvd payload does not start with a valid ftyp box");
            }
            // Samsung's trailing sefd and any bytes after it are outside the MP4 range.
            if (box.type == SEFD) {
                video_end = box.offset;
                break;
            }
            if (box.type == MOOV)
                has_moov = true;
            else if (box.type == MDAT)
                has_mdat = true;
            position = box.end;
        }

        if (!has_moov || !has_mdat) {
            throw new IsoBmffError.INVALID_MP4 (
                "The mpvd payload is not a complete MP4: both moov and mdat boxes are required");
        }
        MpvdVideoRange range = MpvdVideoRange ();
        range.offset = mpvd.payload_offset;
        range.length = video_end - mpvd.payload_offset;
        return range;
    }

    void read_box (FileInputStream input, int64 offset, int64 limit, out Box box) throws Error {
        int64 remaining = limit - offset;
        if (remaining < 8) {
            throw new IsoBmffError.MALFORMED_CONTAINER (
                "Truncated ISO-BMFF box header at offset %lld".printf (offset));
        }

        input.seek (offset, SeekType.SET);
        uint8[] header = new uint8[8];
        size_t bytes_read;
        input.read_all (header, out bytes_read, null);
        if (bytes_read != header.length) {
            throw new IsoBmffError.MALFORMED_CONTAINER (
                "Truncated ISO-BMFF box header at offset %lld".printf (offset));
        }

        uint32 size32 = read_be32 (header, 0);
        int64 header_size = 8;
        int64 box_size;
        if (size32 == 1) {
            header_size = 16;
            if (remaining < header_size) {
                throw new IsoBmffError.MALFORMED_CONTAINER (
                    "Truncated extended ISO-BMFF box header at offset %lld".printf (offset));
            }
            uint8[] large_size_bytes = new uint8[8];
            input.read_all (large_size_bytes, out bytes_read, null);
            if (bytes_read != large_size_bytes.length) {
                throw new IsoBmffError.MALFORMED_CONTAINER (
                    "Truncated extended ISO-BMFF box header at offset %lld".printf (offset));
            }
            uint64 large_size = read_be64 (large_size_bytes, 0);
            if (large_size < (uint64) header_size) {
                throw new IsoBmffError.MALFORMED_CONTAINER (
                    "ISO-BMFF box at offset %lld is smaller than its extended header".printf (offset));
            }
            if (large_size > (uint64) remaining) {
                throw new IsoBmffError.MALFORMED_CONTAINER (
                    "ISO-BMFF box at offset %lld exceeds its enclosing boundary or is truncated".printf (offset));
            }
            box_size = (int64) large_size;
        } else if (size32 == 0) {
            box_size = remaining;
        } else {
            if (size32 < (uint32) header_size) {
                throw new IsoBmffError.MALFORMED_CONTAINER (
                    "ISO-BMFF box at offset %lld is smaller than its header".printf (offset));
            }
            if ((uint64) size32 > (uint64) remaining) {
                throw new IsoBmffError.MALFORMED_CONTAINER (
                    "ISO-BMFF box at offset %lld exceeds its enclosing boundary or is truncated".printf (offset));
            }
            box_size = size32;
        }

        box = Box ();
        box.offset = offset;
        box.end = offset + box_size;
        box.payload_offset = offset + header_size;
        box.payload_size = box_size - header_size;
        box.type = read_be32 (header, 4);
    }

    uint32 read_be32 (uint8[] data, int offset) {
        return ((uint32) data[offset] << 24)
            | ((uint32) data[offset + 1] << 16)
            | ((uint32) data[offset + 2] << 8)
            | (uint32) data[offset + 3];
    }

    uint64 read_be64 (uint8[] data, int offset) {
        return ((uint64) read_be32 (data, offset) << 32)
            | (uint64) read_be32 (data, offset + 4);
    }
}

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

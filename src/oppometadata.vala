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

internal struct LivePhotoConv.OppoJpegInfo {
    int64 insertion_offset;
    int64 mpf_size_offset;
    bool mpf_big_endian;
    uint32 image_count;
}

[Compact (opaque = true)]
internal class LivePhotoConv.OppoMetadata {
    const uint64 LIVE_PHOTO_FLAG = 0x800000;
    const int MPF_SEGMENT_SIZE = 74;

    public static void validate_main_image (string filename) throws Error {
        var file = File.new_for_commandline_arg (filename);
        var jpeg_size = file.query_info ("standard::size", FileQueryInfoFlags.NONE).get_size ();
        var info = read_jpeg_info (file, jpeg_size);
        if (info.image_count != 1) {
            throw new ExportError.METADATA_EXPORT_ERROR (
                "OPPO compatibility currently requires a single-image JPEG, but `%s' declares %u images",
                filename, info.image_count);
        }

        var metadata = new GExiv2.Metadata ();
        metadata.open_path (filename);
        get_flags_for_write (metadata);
    }

    public static int64 validate_live_photo (string filename, int64 video_offset) throws Error {
        var file = File.new_for_commandline_arg (filename);
        var file_size = file.query_info ("standard::size", FileQueryInfoFlags.NONE).get_size ();
        if (video_offset <= 0 || video_offset >= file_size)
            throw new ExportError.METADATA_EXPORT_ERROR ("Invalid JPEG/MP4 boundary for OPPO repair");
        var input = file.read ();
        try {
            var info = inspect_jpeg (input, video_offset);
            if (info.image_count != 1) {
                throw new ExportError.METADATA_EXPORT_ERROR (
                    "OPPO repair currently requires a single-image JPEG, but `%s' declares %u images",
                    filename, info.image_count);
            }
            return validate_mp4_to_eof (input, video_offset, file_size);
        } finally {
            try {
                input.close ();
            } catch {}
        }
    }

    public static void validate_video (string filename) throws Error {
        var file = File.new_for_commandline_arg (filename);
        var file_size = file.query_info ("standard::size", FileQueryInfoFlags.NONE).get_size ();
        var input = file.read ();
        try {
            validate_mp4_to_eof (input, 0, file_size);
        } finally {
            try {
                input.close ();
            } catch {}
        }
    }

    static int64 validate_mp4_to_eof (FileInputStream input, int64 start, int64 file_size) throws Error {
        int64 position = start;
        var seen_moov = false;
        var seen_mdat = false;
        while (position < file_size) {
            if (file_size - position < 8)
                throw new ExportError.METADATA_EXPORT_ERROR ("Truncated MP4 box");
            var header = read_at (input, position, 8);
            for (var index = 4; index < 8; index += 1) {
                if (header[index] < 0x20 || header[index] > 0x7e)
                    throw new ExportError.METADATA_EXPORT_ERROR ("Invalid MP4 box type");
            }
            if (position == start && (header[4] != 'f' || header[5] != 't'
                                      || header[6] != 'y' || header[7] != 'p'))
                throw new ExportError.METADATA_EXPORT_ERROR ("The MP4 video does not start with an ftyp box");

            var short_size = read_u32 (header, 0, true);
            uint64 box_size = short_size;
            var header_size = 8;
            if (short_size == 1) {
                var large_size_bytes = read_at (input, position + 8, 8);
                box_size = 0;
                foreach (var value in large_size_bytes)
                    box_size = (box_size << 8) | value;
                header_size = 16;
            } else if (short_size == 0) {
                box_size = file_size - position;
            }
            if (box_size < header_size || box_size > (uint64) (file_size - position))
                throw new ExportError.METADATA_EXPORT_ERROR ("MP4 data does not end at a valid box boundary");
            if (position == start && (box_size < header_size + 8 || box_size % 4 != 0))
                throw new ExportError.METADATA_EXPORT_ERROR ("Invalid MP4 ftyp box");

            if (header[4] == 'm' && header[5] == 'o' && header[6] == 'o'
                && header[7] == 'v')
                seen_moov = true;
            if (header[4] == 'm' && header[5] == 'd' && header[6] == 'a'
                && header[7] == 't')
                seen_mdat = true;
            position += (int64) box_size;
        }
        if (!seen_moov || !seen_mdat)
            throw new ExportError.METADATA_EXPORT_ERROR ("MP4 video has no complete moov/mdat structure");
        return file_size - start;
    }

    public static bool get_tagflags (GExiv2.Metadata metadata, out uint64 flags) {
        flags = 0;
        try {
            if (!metadata.has_tag ("Exif.Photo.UserComment"))
                return false;
            var comment = metadata.get_tag_string ("Exif.Photo.UserComment");
            if (comment == null)
                return false;
            var value = comment.strip ();
            if (value.ascii_down ().has_prefix ("charset=")) {
                var separator = value.index_of_char (' ');
                if (separator < 0)
                    return false;
                value = value.substring (separator + 1).strip ();
            }
            var normalized = value.ascii_down ();
            var prefix_length = 0;
            if (normalized.has_prefix ("asciioplus_")) {
                prefix_length = 11;
            } else if (normalized.has_prefix ("asciioppo_")) {
                prefix_length = 10;
            } else if (normalized.has_prefix ("oplus_")) {
                prefix_length = 6;
            } else if (normalized.has_prefix ("oppo_")) {
                prefix_length = 5;
            } else {
                return false;
            }
            var number = value.substring (prefix_length).strip ();
            return uint64.try_parse (number, out flags);
        } catch {
            return false;
        }
    }

    static uint64 get_flags_for_write (GExiv2.Metadata metadata) throws Error {
        uint64 flags = LIVE_PHOTO_FLAG;
        try {
            if (metadata.has_tag ("Exif.Photo.UserComment")) {
                uint64 existing_flags;
                if (get_tagflags (metadata, out existing_flags)) {
                    flags = existing_flags | LIVE_PHOTO_FLAG;
                } else {
                    throw new ExportError.METADATA_EXPORT_ERROR (
                        "OPPO compatibility would overwrite an existing non-OPlus EXIF UserComment");
                }
            }
        } catch (ExportError e) {
            throw e;
        } catch (Error e) {
            throw new ExportError.METADATA_EXPORT_ERROR ("Cannot read EXIF UserComment: %s", e.message);
        }
        return flags;
    }

    public static void write_tags (GExiv2.Metadata metadata, int64 video_length,
                                   string presentation_timestamp_us) throws Error {
        var flags = get_flags_for_write (metadata);
        replace_tag (metadata, "Exif.Photo.UserComment", "charset=Ascii Oplus_" + flags.to_string ());
        replace_tag (metadata, "Xmp.OpCamera.MotionPhotoPrimaryPresentationTimestampUs",
                     presentation_timestamp_us);
        replace_tag (metadata, "Xmp.OpCamera.MotionPhotoOwner", "oplus");
        replace_tag (metadata, "Xmp.OpCamera.OLivePhotoVersion", "2");
        replace_tag (metadata, "Xmp.OpCamera.VideoLength", video_length.to_string ());
    }

    public static void verify_tags (string filename, int64 video_length,
                                    string presentation_timestamp_us) throws Error {
        var metadata = new GExiv2.Metadata ();
        metadata.open_path (filename);
        verify_tag (metadata, "Xmp.OpCamera.MotionPhotoPrimaryPresentationTimestampUs",
                    presentation_timestamp_us);
        verify_tag (metadata, "Xmp.OpCamera.MotionPhotoOwner", "oplus");
        verify_tag (metadata, "Xmp.OpCamera.OLivePhotoVersion", "2");
        verify_tag (metadata, "Xmp.OpCamera.VideoLength", video_length.to_string ());
        uint64 flags;
        if (!get_tagflags (metadata, out flags) || (flags & LIVE_PHOTO_FLAG) == 0) {
            throw new ExportError.METADATA_EXPORT_ERROR (
                "Cannot verify the OPPO live-photo flag in `%s'", filename);
        }
    }

    public static void ensure_mpf (string filename, int64 jpeg_size) throws Error {
        if (jpeg_size <= 0 || jpeg_size > uint32.MAX)
            throw new ExportError.METADATA_EXPORT_ERROR ("Invalid JPEG size for OPPO MPF metadata: %lld", jpeg_size);

        var file = File.new_for_commandline_arg (filename);
        var info = read_jpeg_info (file, jpeg_size);
        if (info.image_count != 1)
            throw new ExportError.METADATA_EXPORT_ERROR (
                "OPPO MPF update refuses a multi-image JPEG (%u images)", info.image_count);

        if (info.mpf_size_offset >= 0) {
            var size_bytes = new uint8[4];
            store_u32 (size_bytes, 0, (uint32) jpeg_size, info.mpf_big_endian);
            var stream = file.open_readwrite ();
            try {
                stream.seek (info.mpf_size_offset, SeekType.SET);
                size_t bytes_written;
                stream.output_stream.write_all (size_bytes, out bytes_written, null);
                stream.output_stream.flush ();
            } finally {
                try {
                    stream.close ();
                } catch {}
            }
            return;
        }

        if (jpeg_size > uint32.MAX - MPF_SEGMENT_SIZE)
            throw new ExportError.METADATA_EXPORT_ERROR ("JPEG is too large for OPPO MPF metadata");
        insert_segment (file, info.insertion_offset,
                        build_mpf_segment ((uint32) (jpeg_size + MPF_SEGMENT_SIZE)));
    }

    static void verify_tag (GExiv2.Metadata metadata, string tag, string expected) throws Error {
        if (!metadata.has_tag (tag) || metadata.get_tag_string (tag) != expected) {
            throw new ExportError.METADATA_EXPORT_ERROR ("Cannot verify OPPO metadata tag %s", tag);
        }
    }

    static void replace_tag (GExiv2.Metadata metadata, string tag, string value) throws Error {
        try {
            if (metadata.has_tag (tag))
                metadata.clear_tag (tag);
        } catch {}
        metadata.set_tag_string (tag, value);
    }

    static OppoJpegInfo read_jpeg_info (File file, int64 jpeg_size) throws Error {
        var input = file.read ();
        try {
            return inspect_jpeg (input, jpeg_size);
        } finally {
            try {
                input.close ();
            } catch {}
        }
    }

    static OppoJpegInfo inspect_jpeg (FileInputStream input, int64 jpeg_size) throws Error {
        OppoJpegInfo info = OppoJpegInfo ();
        info.insertion_offset = 2;
        info.mpf_size_offset = -1;
        info.mpf_big_endian = true;
        info.image_count = 1;
        if (jpeg_size < 8 || jpeg_size > int.MAX)
            throw new ExportError.METADATA_EXPORT_ERROR ("Invalid JPEG size for OPPO metadata");

        input.seek (0, SeekType.SET);
        var jpeg = new uint8[(int) jpeg_size];
        size_t bytes_read;
        input.read_all (jpeg, out bytes_read, null);
        if (bytes_read != jpeg_size)
            throw new ExportError.METADATA_EXPORT_ERROR ("Unexpected end of JPEG data");
        if (jpeg[0] != 0xff || jpeg[1] != 0xd8)
            throw new ExportError.METADATA_EXPORT_ERROR ("OPPO compatibility requires a JPEG main image");

        var position = 2;
        var initial_segments = true;
        var found_mpf = false;
        var found_sos = false;
        var found_eoi = false;
        while (position < jpeg.length) {
            if (jpeg.length - position < 2 || jpeg[position] != 0xff)
                throw new ExportError.METADATA_EXPORT_ERROR ("Invalid JPEG marker structure");
            if (jpeg[position + 1] == 0xff) {
                position += 1;
                continue;
            }

            var marker = jpeg[position + 1];
            if (marker == 0xd9) {
                found_eoi = true;
                position += 2;
                break;
            }
            if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
                position += 2;
                continue;
            }
            if (jpeg.length - position < 4)
                throw new ExportError.METADATA_EXPORT_ERROR ("Truncated JPEG segment");

            var segment_length = read_u16 (jpeg, position + 2, true);
            if (segment_length < 2 || segment_length > jpeg.length - position - 2)
                throw new ExportError.METADATA_EXPORT_ERROR ("Invalid JPEG segment length");
            var next_position = position + 2 + segment_length;

            var is_sof = marker >= 0xc0 && marker <= 0xcf
                && marker != 0xc4 && marker != 0xc8 && marker != 0xcc;
            if (marker == 0xdb || marker == 0xc4 || is_sof)
                initial_segments = false;

            if (!found_sos && marker >= 0xe0 && marker <= 0xef) {
                if (initial_segments)
                    info.insertion_offset = next_position;
                if (marker == 0xe2 && segment_length >= 6) {
                    var body = jpeg[position + 4:next_position];
                    if (body.length >= 4 && body[0] == 'M' && body[1] == 'P'
                        && body[2] == 'F' && body[3] == 0) {
                        if (found_mpf)
                            throw new ExportError.METADATA_EXPORT_ERROR ("Duplicate MPF APP2 segments");
                        found_mpf = true;
                        info.mpf_size_offset = parse_mpf (
                            body, position + 4, out info.mpf_big_endian, out info.image_count);
                    }
                }
            }

            position = next_position;
            if (marker != 0xda)
                continue;
            found_sos = true;
            while (position < jpeg.length) {
                if (jpeg[position] != 0xff) {
                    position += 1;
                    continue;
                }
                if (jpeg.length - position < 2)
                    throw new ExportError.METADATA_EXPORT_ERROR ("Truncated JPEG entropy data");
                var next_marker = jpeg[position + 1];
                if (next_marker == 0x00 || (next_marker >= 0xd0 && next_marker <= 0xd7)) {
                    position += 2;
                } else if (next_marker == 0xff) {
                    position += 1;
                } else {
                    break;
                }
            }
        }
        if (!found_sos || !found_eoi || position != jpeg.length) {
            throw new ExportError.METADATA_EXPORT_ERROR (
                "OPPO compatibility requires exactly one unpadded JPEG before the video");
        }
        return info;
    }

    static int64 parse_mpf (uint8[] body, int64 body_position,
                            out bool big_endian, out uint32 image_count) throws Error {
        big_endian = true;
        image_count = 0;
        if (body.length < 12)
            throw new ExportError.METADATA_EXPORT_ERROR ("Truncated MPF segment");
        const int tiff = 4;
        if (body[tiff] == 'M' && body[tiff + 1] == 'M') {
            big_endian = true;
        } else if (body[tiff] == 'I' && body[tiff + 1] == 'I') {
            big_endian = false;
        } else {
            throw new ExportError.METADATA_EXPORT_ERROR ("Invalid MPF byte order");
        }
        if (read_u16 (body, tiff + 2, big_endian) != 42)
            throw new ExportError.METADATA_EXPORT_ERROR ("Invalid MPF TIFF header");

        var ifd_relative = read_u32 (body, tiff + 4, big_endian);
        if (ifd_relative > body.length - tiff - 2)
            throw new ExportError.METADATA_EXPORT_ERROR ("MPF IFD offset is out of bounds");
        var ifd = tiff + (int) ifd_relative;
        var entry_count = read_u16 (body, ifd, big_endian);
        if (entry_count > (body.length - ifd - 6) / 12)
            throw new ExportError.METADATA_EXPORT_ERROR ("MPF IFD is truncated");

        int64 size_offset = -1;
        uint32 mp_entry_bytes = 0;
        for (var index = 0; index < entry_count; index += 1) {
            var entry = ifd + 2 + index * 12;
            var tag = read_u16 (body, entry, big_endian);
            if (tag == 0xb001) {
                if (read_u16 (body, entry + 2, big_endian) != 4
                    || read_u32 (body, entry + 4, big_endian) != 1)
                    throw new ExportError.METADATA_EXPORT_ERROR ("Invalid MPF NumberOfImages tag");
                image_count = read_u32 (body, entry + 8, big_endian);
            } else if (tag == 0xb002) {
                if (read_u16 (body, entry + 2, big_endian) != 7)
                    throw new ExportError.METADATA_EXPORT_ERROR ("Invalid MPF MPEntry type");
                mp_entry_bytes = read_u32 (body, entry + 4, big_endian);
                if (mp_entry_bytes < 16)
                    throw new ExportError.METADATA_EXPORT_ERROR ("MPF has no complete primary MPEntry");
                var mp_entry_relative = read_u32 (body, entry + 8, big_endian);
                if (mp_entry_relative > body.length - tiff - 8
                    || mp_entry_bytes > body.length - tiff - (int) mp_entry_relative)
                    throw new ExportError.METADATA_EXPORT_ERROR ("MPEntry offset is out of bounds");
                var mp_entry = tiff + (int) mp_entry_relative;
                var attributes = read_u32 (body, mp_entry, big_endian);
                if ((attributes & 0x07000000) != 0
                    || (attributes & 0x00ffffff) != 0x00030000
                    || (attributes & 0xd8000000) != 0
                    || read_u32 (body, mp_entry + 8, big_endian) != 0) {
                    throw new ExportError.METADATA_EXPORT_ERROR (
                        "MPF primary entry is not a Baseline MP Primary JPEG");
                }
                size_offset = body_position + mp_entry + 4;
            }
        }
        if (image_count == 0 || size_offset < 0
            || (uint64) image_count * 16 > mp_entry_bytes)
            throw new ExportError.METADATA_EXPORT_ERROR ("Incomplete MPF index");
        return size_offset;
    }

    static uint8[] build_mpf_segment (uint32 image_size) {
        var segment = new uint8[MPF_SEGMENT_SIZE];
        segment[0] = 0xff;
        segment[1] = 0xe2;
        store_u16 (segment, 2, 72, true);
        segment[4] = 'M';
        segment[5] = 'P';
        segment[6] = 'F';
        segment[7] = 0;
        segment[8] = 'M';
        segment[9] = 'M';
        store_u16 (segment, 10, 42, true);
        store_u32 (segment, 12, 8, true);
        store_u16 (segment, 16, 3, true);

        store_u16 (segment, 18, 0xb000, true);
        store_u16 (segment, 20, 7, true);
        store_u32 (segment, 22, 4, true);
        segment[26] = '0';
        segment[27] = '1';
        segment[28] = '0';
        segment[29] = '0';

        store_u16 (segment, 30, 0xb001, true);
        store_u16 (segment, 32, 4, true);
        store_u32 (segment, 34, 1, true);
        store_u32 (segment, 38, 1, true);

        store_u16 (segment, 42, 0xb002, true);
        store_u16 (segment, 44, 7, true);
        store_u32 (segment, 46, 16, true);
        store_u32 (segment, 50, 50, true);
        store_u32 (segment, 54, 0, true);

        store_u32 (segment, 58, 0x00030000, true);
        store_u32 (segment, 62, image_size, true);
        store_u32 (segment, 66, 0, true);
        store_u16 (segment, 70, 0, true);
        store_u16 (segment, 72, 0, true);
        return segment;
    }

    static void insert_segment (File file, int64 insertion_offset, uint8[] segment) throws Error {
        var parent = file.get_parent ();
        var temporary = parent.get_child ("." + file.get_basename () + ".oppo-" + Uuid.string_random () + ".tmp");
        FileInputStream? input = null;
        FileOutputStream? output = null;
        var committed = false;
        try {
            input = file.read ();
            output = temporary.create (FileCreateFlags.NONE);
            Utils.write_stream_before (input, output, insertion_offset);
            size_t bytes_written;
            output.write_all (segment, out bytes_written, null);
            input.seek (insertion_offset, SeekType.SET);
            Utils.write_stream (input, output);
            output.flush ();
            output.close ();
            input.close ();
            try {
                var info = file.query_info ("unix::mode", FileQueryInfoFlags.NONE);
                if (info.has_attribute ("unix::mode")) {
                    temporary.set_attribute_uint32 ("unix::mode", info.get_attribute_uint32 ("unix::mode"),
                                                    FileQueryInfoFlags.NONE);
                }
            } catch {}
            temporary.move (file, FileCopyFlags.OVERWRITE, null);
            committed = true;
        } finally {
            if (output != null) {
                try {
                    output.close ();
                } catch {}
            }
            if (input != null) {
                try {
                    input.close ();
                } catch {}
            }
            if (!committed) {
                try {
                    temporary.delete ();
                } catch {}
            }
        }
    }

    static uint8[] read_at (FileInputStream input, int64 offset, int size) throws Error {
        if (offset < 0 || size < 1)
            throw new ExportError.METADATA_EXPORT_ERROR ("Invalid file read boundary");
        input.seek (offset, SeekType.SET);
        var data = new uint8[size];
        size_t bytes_read;
        input.read_all (data, out bytes_read, null);
        if (bytes_read != size)
            throw new ExportError.METADATA_EXPORT_ERROR ("Unexpected end of file");
        return data;
    }

    static uint16 read_u16 (uint8[] data, int offset, bool big_endian) {
        if (big_endian)
            return (uint16) ((data[offset] << 8) | data[offset + 1]);
        return (uint16) (data[offset] | (data[offset + 1] << 8));
    }

    static uint32 read_u32 (uint8[] data, int offset, bool big_endian) {
        if (big_endian) {
            return ((uint32) data[offset] << 24)
                | ((uint32) data[offset + 1] << 16)
                | ((uint32) data[offset + 2] << 8)
                | data[offset + 3];
        }
        return data[offset]
            | ((uint32) data[offset + 1] << 8)
            | ((uint32) data[offset + 2] << 16)
            | ((uint32) data[offset + 3] << 24);
    }

    static void store_u16 (uint8[] data, int offset, uint16 value, bool big_endian) {
        if (big_endian) {
            data[offset] = (uint8) (value >> 8);
            data[offset + 1] = (uint8) value;
        } else {
            data[offset] = (uint8) value;
            data[offset + 1] = (uint8) (value >> 8);
        }
    }

    static void store_u32 (uint8[] data, int offset, uint32 value, bool big_endian) {
        if (big_endian) {
            data[offset] = (uint8) (value >> 24);
            data[offset + 1] = (uint8) (value >> 16);
            data[offset + 2] = (uint8) (value >> 8);
            data[offset + 3] = (uint8) value;
        } else {
            data[offset] = (uint8) value;
            data[offset + 1] = (uint8) (value >> 8);
            data[offset + 2] = (uint8) (value >> 16);
            data[offset + 3] = (uint8) (value >> 24);
        }
    }
}

# Live Photo Converter

* [中文版本](README-zh.md)

Live Photo Converter is a cross-platform tool for processing live photos. It can combine a static image and a video into a live photo or extract the static image and video from a live photo. It can also export every frame of a video as an image.

## Features

- `live-photo-conv`
  - Create live photos
  - Extract static images and videos from live photos
  - Export every frame of a video as an image
  - Support exporting metadata
- `copy-exif`
  - Copy all metadata from one image to another

## Background [(Chinese Introduction)](https://wszqkzqk.github.io/2024/08/01/%E8%A7%A3%E6%9E%90Android%E7%9A%84%E5%8A%A8%E6%80%81%E7%85%A7%E7%89%87/)

Android live photos are a gradually popularizing media file format that combines a video with audio and a static image to form a dynamic photo. This type of photo is supported on various devices, such as Google's Pixel series, Samsung's Galaxy series, and most models from manufacturers like Xiaomi.

Essentially, an Android live photo appends a video file directly to the end of a static image. This video file contains both audio and video streams. The position of the video file is marked using `XMP` metadata, allowing quick location of the video file during parsing. The advantage of this format is that it adds dynamic effects to the image without altering the original image. Since this extension is not a standard for image formats, such images will only be displayed as static images in unsupported image viewers.

This tool can be used for extracting, editing, and composing such live photos.

## Build

### Dependencies

* Build Dependencies
  * Meson
  * Vala
  * GExiv2
  * GStreamer (optional, used for exporting images from attached videos, otherwise FFmpeg commands are used)
    * `gstreamer`
    * `gst-plugins-base-libs`
  * gdk-pixbuf2 (optional, used for exporting images from attached videos, otherwise FFmpeg commands are used)
  * gobject-introspection (optional, used for generating GObject Introspection information)
* Runtime Dependencies
  * GLib
    * GObject
    * GIO
  * GExiv2
  * GStreamer (required when built with GStreamer support)
    * `gstreamer`
    * `gst-plugins-base-libs`
  * gdk-pixbuf2 (required when built with GStreamer support)
    * `gdk-pixbuf2`
    * To support more export formats, you can install optional dependencies such as:
      * `libavif`: .avif
      * `libheif`: .heif, .heic, and .avif
      * `libjxl`: .jxl
      * `webp-pixbuf-loader`: .webp
  * FFmpeg (optional, required when not built with GStreamer support and need to export images from attached videos)

For example, to install dependencies on Arch Linux:

```bash
sudo pacman -S --needed glib2 libgexiv2 meson vala gstreamer gst-plugins-base-libs gdk-pixbuf2 gobject-introspection
```

To install dependencies on Windows by MSYS2 (UCRT64 environment):

```bash
pacman -S --needed mingw-w64-ucrt-x86_64-glib2 mingw-w64-ucrt-x86_64-gexiv2 mingw-w64-ucrt-x86_64-meson mingw-w64-ucrt-x86_64-vala mingw-w64-ucrt-x86_64-gstreamer mingw-w64-ucrt-x86_64-gst-plugins-base-libs mingw-w64-ucrt-x86_64-gdk-pixbuf2 mingw-w64-ucrt-x86_64-gobject-introspection
```

### Compilation

Use Meson and Ninja to build the project. When configuring the build with Meson, it will automatically detect if GStreamer is supported by default (equivalent to `-Dgst=auto`):

```bash
meson setup builddir --buildtype=release
```

To force the use of GStreamer, you can use `-D gst=enabled`:

```bash
meson setup builddir --buildtype=release -D gst=enabled
```

To force disable GStreamer, you can use `-D gst=disabled`:

```bash
meson setup builddir --buildtype=release -D gst=disabled
```

Then compile the project:

```bash
meson compile -C builddir
```

## Usage

### `live-photo-conv`

#### Command-Line Options

```
live-photo-conv [OPTION…] - Extract or Make Live Photos
```

Please run `live-photo-conv --help` to see the command-line options.

#### Examples

Create a live photo:

```bash
live-photo-conv --make --image /path/to/image.jpg --video /path/to/video.mp4 --live-photo /path/to/output.jpg
```

Extract a live photo:

```bash
live-photo-conv --extract --live-photo /path/to/live_photo.jpg --dest-dir /path/to/dest --frame-to-photos --img-format avif
```

You can also use URI to specify the path:

```bash
live-photo-conv --make --image file:///path/to/image.jpg --video file:///path/to/video.mp4 --live-photo file:///path/to/output.jpg
```

### `copy-exif`

#### Command-Line Options

```
copy-exif [OPTION…] <exif-source-img> <dest-img> - Copy all metadata from one image to another
```

Please run `copy-exif --help` to see the command-line options.

#### Examples

Copy metadata from one image to another:

```bash
copy-exif /path/to/exif-source.jpg /path/to/dest.webp
```

## Exporting Images from Embedded Videos: Using FFmpeg or GStreamer?

If GStreamer support is enabled during the build, GStreamer will be used by default to export images from embedded videos. Otherwise, the program will attempt to create an FFmpeg subprocess via command to export images. Even with GStreamer support enabled, you can use the `--use-ffmpeg` option to use FFmpeg.

The speed of exporting images using GStreamer versus FFmpeg is not always consistent. The GStreamer-based video export tool built by the author encodes in parallel, and the number of jobs can be controlled by adjusting the `-j`/`--jobs` option. However, the author has not optimized the decoding part of GStreamer very well; each frame undergoes a forced color space conversion, which may introduce performance overhead. Therefore, in summary:

* When the selected image encoding is slow, GStreamer exports images faster.
* When the selected image encoding is fast, FFmpeg exports images faster.

## License

This project is licensed under the LGPL-2.1-or-later license. For more details, see the `COPYING` file.

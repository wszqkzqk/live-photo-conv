# Live Photo Converter

* [Chinese Version](README-zh.md)

Live Photo Converter is a cross-platform tool for processing live photos. It can combine a static image and a video into a live photo, convert a video directly into a live photo, repair live photos that fail to parse due to broken metadata, extract the static image and video from a live photo, or export every frame of the video as an image.

## Features

- `live-photo-conv`
  - Create a live photo
  - Extract static image and video from a live photo
  - Repair a live photo with broken XMP metadata
  - Export every frame of a live photo's video as an image
  - Support exporting metadata
- `copy-img-meta`
  - Copy all metadata from one image to another
  - Options to choose or exclude certain metadata types
- `liblivephototools`
  - A library that provides functions for creating and extracting live photos, as well as exporting frames from videos
  - The library can be used in **any** language that supports **GObject Introspection**

## Background [(Chinese Introduction)](https://wszqkzqk.github.io/2024/08/01/%E8%A7%A3%E6%9E%90Android%E7%9A%84%E5%8A%A8%E6%80%81%E7%85%A7%E7%89%87/)

Android live photos are a gradually popularizing media file format that combines a video with audio and a static image to form a live photo. This type of photo is supported on various devices, such as Google's Pixel series, Samsung's Galaxy series, and most models from manufacturers like Xiaomi.

Essentially, an Android live photo appends a video file directly to the end of a static image. This video file contains both audio and video streams. The position of the video file is marked using `XMP` metadata, allowing quick location of the video file during parsing. The advantage of this format is that it adds dynamic effects to the image without altering the original image. Since this extension is not a standard for image formats, such images will only be displayed as static images in unsupported image viewers.

This tool can be used for extracting, repairing, editing, and composing such live photos.

## Build Scripts

This project provides build scripts for Arch Linux and Windows (MSYS2) environments.

#### Arch Linux

On Arch Linux, you can install directly from the AUR using an AUR helper like `paru`:

```bash
paru -S live-photo-conv
```

Alternatively, you can manually clone the AUR repository and build/install:

```bash
git clone https://aur.archlinux.org/live-photo-conv.git
cd live-photo-conv
makepkg -si
```

#### Windows (MSYS2)

On Windows (MSYS2), you can use the provided [`PKGBUILD`](https://gist.github.com/wszqkzqk/052a48feb5b84a469ee43231df91dc9d) to build. For example, execute the following commands in the `bash` shell of the MSYS2 UCRT64 environment:

```bash
mkdir live-photo-conv
cd live-photo-conv
wget https://gist.githubusercontent.com/wszqkzqk/052a48feb5b84a469ee43231df91dc9d/raw/PKGBUILD
makepkg-mingw -si
```

## Manual Build

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
    * `gst-plugins-good`
    * `gst-plugins-bad`
    * `gst-plugin-va` (optional, for hardware acceleration)
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
sudo pacman -S --needed glib2 libgexiv2 meson vala gstreamer gst-plugins-base-libs gdk-pixbuf2 gobject-introspection gst-plugins-good gst-plugins-bad gst-plugin-va
```

To install dependencies on Windows by MSYS2 (UCRT64 environment):

```bash
pacman -S --needed mingw-w64-ucrt-x86_64-glib2 mingw-w64-ucrt-x86_64-cc  mingw-w64-ucrt-x86_64-gexiv2 mingw-w64-ucrt-x86_64-meson mingw-w64-ucrt-x86_64-vala mingw-w64-ucrt-x86_64-gstreamer mingw-w64-ucrt-x86_64-gst-plugins-base mingw-w64-ucrt-x86_64-gdk-pixbuf2 mingw-w64-ucrt-x86_64-gobject-introspection mingw-w64-ucrt-x86_64-gst-plugins-good mingw-w64-ucrt-x86_64-gst-plugins-bad
```

### Compilation

Use Meson and Ninja to build the project. When configuring the build with Meson, it automatically detects whether GStreamer is supported and whether GObject Introspection information can be generated.

Meson build options:

* `gst`
  * Whether to enable GStreamer
  * Possible values are `auto`, `enabled`, `disabled`. Default is `auto`.
* `gir`
  * Whether to generate GObject Introspection information
  * Possible values are `auto`, `enabled`, `disabled`. Default is `auto`.
* `docs`
  * Whether to generate documentation
  * Possible values are `auto`, `enabled`, `disabled`. Default is `auto`.

You can configure the build with the following command:

```bash
meson setup builddir --buildtype=release
```

If you do not want to generate GObject Introspection information, for example, you can disable it with the following command:

```bash
meson setup builddir --buildtype=release -D gir=disabled
```

Then compile the project:

```bash
meson compile -C builddir
```

Install the project:

```bash
meson install -C builddir
```

## Usage

### `live-photo-conv`

#### Command-Line Options

```
Usage:
  live-photo-conv [OPTION…] - Extract, Repair or Make Live Photos

Options:
  -h, --help                        Show help message
  -v, --version                     Display version number
  --color=LEVEL                     Color level of log, 0 for no color, 1 for auto, 2 for always, defaults to 1
  -g, --make                        Make a live photo
  -e, --extract                     Extract a live photo (default)
  -r, --repair                      Repair a live photo from missing XMP metadata
  --force-repair                    Force repair a live photo (force update video offset in XMP metadata)
  --repair-with-video-size=SIZE     Force repair a live photo with the specified video size
  -i, --image=PATH                  The path to the main static image file
  -m, --video=PATH                  The path to the video file
  -p, --live-photo=PATH             The destination path for the live image file. If not provided in 'make' mode, a default destination path will be generated based on the main static image file
  -d, --dest-dir=PATH               The destination directory to export
  --export-metadata                 Export metadata (default)
  --no-export-metadata              Do not export metadata
  --frame-to-photos                 Export every frame of a live photo's video as a photo
  -f, --img-format=FORMAT           The format of the image exported from video
  --minimal                         Minimal metadata export, ignore unspecified exports
  -T, --threads=NUM                 Number of threads to use for extracting, 0 for auto (not work in FFmpeg mode)
  --use-ffmpeg                      Use FFmpeg to extract insdead of GStreamer
  --use-gst                         Use GStreamer to extract insdead of FFmpeg (default)
```

Please run `live-photo-conv --help` to see all command line options. (If GStreamer support is not enabled, the `--use-ffmpeg` and `--use-gst` options will not be available)

#### Examples

Create a live photo:

```bash
live-photo-conv --make --image /path/to/image.jpg --video /path/to/video.mp4 --live-photo /path/to/output.jpg
```

Convert a video to a live photo:

```bash
live-photo-conv --make --video /path/to/video.mp4 --live-photo /path/to/output.jpg
```

Extract a live photo:

```bash
live-photo-conv --extract --live-photo /path/to/live_photo.jpg --dest-dir /path/to/dest --frame-to-photos --img-format avif
```

You can also use URI to specify the path:

```bash
live-photo-conv --make --image file:///path/to/image.jpg --video file:///path/to/video.mp4 --live-photo file:///path/to/output.jpg
```

Repair a live photo:

```bash
live-photo-conv --repair --live-photo /path/to/live_photo.jpg
```

### `copy-img-meta`

#### Command-Line Options

```
Usage:
  copy-img-meta [OPTION…] <exif-source-img> <dest-img> - Copy all metadata from one image to another

Options:
  -h, --help         Show help message
  -v, --version      Display version number
  --color=LEVEL      Color level of log, 0 for no color, 1 for auto, 2 for always, defaults to 1
  --exclude-exif     Do not copy EXIF data
  --with-exif        Copy EXIF data (default)
  --exclude-xmp      Do not copy XMP data
  --with-xmp         Copy XMP data (default)
  --exclude-iptc     Do not copy IPTC data
  --with-iptc        Copy IPTC data (default)
```

Please run `copy-img-meta --help` to see the command-line options.

#### Examples

Copy metadata from one image to another:

```bash
copy-img-meta /path/to/exif-source.jpg /path/to/dest.webp
```

Choose not to copy certain metadata:

```bash
copy-img-meta --exclude-xmp --exclude-iptc /path/to/exif-source.jpg /path/to/dest.webp
```

### `liblivephototools`

* **Warning:** The API of this library may change with future versions.

`liblivephototools` is a library for creating and extracting live photos, as well as exporting frames from embedded videos. It can be used in **any** language that supports **GObject Introspection**, such as C, Vala, Rust, C++, Python, etc.

#### Example

For example, in Python, make sure the `python-gobject` package has been installed, and then import the library:

```python
import gi
gi.require_version('LivePhotoTools', '0.3') # Adjust according to the actual version number
from gi.repository import LivePhotoTools
```

Usage example:
  
```python
# Load a live photo
livephoto = LivePhotoTools.LivePhotoGst.new("MVIMG_20241104_164717.jpg")
# Extract the static image from the live photo
livephoto.export_main_image()
# Extract the video from the live photo
livephoto.export_video()
# Export frames from the embedded video
livephoto.splites_images_from_video(None, None, 0)
```

```python
# Create a live photo
livemaker = LivePhotoTools.LiveMakerGst.new('VID_20241104_164717.mp4', 'IMG_20241104_164717.jpg')
# Export
livemaker.export()
```

## Exporting Images from Embedded Videos: Using FFmpeg or GStreamer?

If GStreamer support is enabled during the build, GStreamer will be used by default to export images from embedded videos. Otherwise, the program will attempt to create an FFmpeg subprocess via command to export images. Even with GStreamer support enabled, you can use the `--use-ffmpeg` option to use FFmpeg.

The speed of exporting images using GStreamer versus FFmpeg is not always consistent. The GStreamer-based video export tool built by me encodes in parallel, and the number of threads can be controlled by adjusting the `-T`/`--threads` option. However, I has not optimized the decoding part of GStreamer very well; each frame undergoes a forced color space conversion （due to the [limitation of `gdk-pixbuf2`](https://docs.gtk.org/gdk-pixbuf/property.Pixbuf.colorspace.html)）, which may introduce performance overhead. Therefore, in summary:

* When the selected image encoding is slow, GStreamer exports images faster.
* When the selected image encoding is fast, FFmpeg exports images faster.

## License

This project is licensed under the LGPL-2.1-or-later license. For more details, see the `COPYING` file.

## FAQ

### Path Encoding on Windows: Unable to Read/Write Metadata for Paths Containing Non-ASCII Characters

Due to limitations in Exiv2 and incomplete bindings in GExiv2, it is currently not possible on Windows to read or write metadata for paths that contain non-ASCII characters.

### Fragmentation Among Android Manufacturers: Live Photos Not Recognized

Due to the fragmentation among Android phone manufacturers, different vendors may require proprietary metadata in live photos to correctly recognize them. As a result, live photos generated by this tool may not be recognized on some devices.

Workarounds:

* Take a photo (usually not live photo) with a phone from the respective manufacturer.
* Use the `copy-img-meta` tool to copy the metadata from that photo to the generated live photo.
* If the phone recognizes the live photo but fails to play it, repair the live photo using the `live-photo-conv` tool:
  * For example, run `live-photo-conv --repair -p /path/to/live_photo.jpg`
  * Or force a repair with `live-photo-conv --force-repair -p /path/to/live_photo.jpg`
  * In rare cases where the repair still fails, you can try specifying the embedded video size using `live-photo-conv --repair-with-video-size=SIZE -p /path/to/live_photo.jpg` (usually not necessary)

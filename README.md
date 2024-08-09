# Motion Photo Converter

* [中文版本](README-zh.md)

Motion Photo Converter is a tool for processing motion photos. It can combine a static image and a video into a motion photo or extract the static image and video from a motion photo. It can also export every frame of a video as an image.

## Features

- Create motion photos
- Extract static images and videos from motion photos
- Export every frame of a video as an image
- Support exporting metadata

## Build

### Dependencies

* Runtime dependencies
  * GLib
    * GObject
    * GIO
  * GExiv2
  * FFmpeg
* Build dependencies
  * Meson
  * Vala

For example, to install dependencies on Arch Linux:

```bash
sudo pacman -S --needed glib2 gexiv2 ffmpeg meson vala
```

To install dependencies on MSYS2 (UCRT64 environment):

```bash
pacman -S --needed mingw-w64-ucrt-x86_64-glib2 mingw-w64-ucrt-x86_64-gexiv2 mingw-w64-ucrt-x86_64-ffmpeg mingw-w64-ucrt-x86_64-meson mingw-w64-ucrt-x86_64-vala
```

### Compilation

Build the project using Meson and Ninja:

```bash
meson setup builddir --buildtype=release
meson compile -C builddir
```

## Usage

### Command-Line Options

- `-h, --help`: Show help message
- `-v, --version`: Display version number
- `-g, --make`: Create a motion photo
- `-e, --extract`: Extract a motion photo (default)
- `-i, --image PATH`: Path to the static image file
- `-m, --video PATH`: Path to the video file
- `-p, --motion-photo PATH`: Destination path for the motion photo file. If not provided in `make` mode, a default path will be generated based on the static image file
- `-d, --dest-dir PATH`: Destination directory for export
- `--export-metadata`: Export metadata (default)
- `--no-export-metadata`: Do not export metadata
- `--frame-to-photos`: Export every frame of the video as an image
- `-f, --img-format FORMAT`: Format of the image exported from the video
- `--color LEVEL`: Color level, 0 for no color, 1 for auto, 2 for always, defaults to 1

### Examples

Create a motion photo:

```sh
motion-photo-conv --make --image /path/to/image.jpg --video /path/to/video.mp4 --motion-photo /path/to/output.jpg
```

Extract a motion photo:

```sh
motion-photo-conv --extract --motion-photo /path/to/motion_photo.jpg --dest-dir /path/to/dest --frame-to-photos --img-format avif
```

## License

This project is licensed under the LGPL-2.1-or-later license. For more details, see the `COPYING` file.

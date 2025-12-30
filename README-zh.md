# Live Photo Converter

<div align="center">
  <img src="assets/logo.png" alt="Live Photo Converter" style="width: 500px; max-width: 100%;" />
</div>

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/wszqkzqk/live-photo-conv)

* [English Version](README.md)

Live Photo Converter 是一个用于处理动态照片的跨平台的工具。它可以将静态图像和视频合成为动态照片，直接将视频转化为动态照片，修复受损的动态照片，或者从动态照片中提取静态图像和视频，还可以将视频的每一帧导出为图片。

## 功能

- `live-photo-make`
  - 从图片和视频创建动态照片
- `live-photo-extract`
  - 从动态照片中提取图片、视频和视频帧
- `live-photo-repair`
  - 修复损坏的动态照片
- `live-photo-conv`
  - 功能全面的通用命令，用于创建、提取和修复动态照片
- `copy-img-meta`
  - 从一张图片复制元数据到另一张图片
  - 可以选择复制或排除 EXIF、XMP、IPTC 元数据
- `liblivephototools`
  - 一个可用于创建和提取动态照片以及从内嵌视频中导出帧的库
  - 可以在支持 **GObject Introspection** 的**任何**语言中使用

## [背景](https://wszqkzqk.github.io/2024/08/01/%E8%A7%A3%E6%9E%90Android%E7%9A%84%E5%8A%A8%E6%80%81%E7%85%A7%E7%89%87/)

Android 的动态照片是一种逐渐普及的媒体文件格式，它可以将包含音频的视频与静态图片结合在一起，形成一个动态的照片。这种照片已经在多种机型上得到了支持，例如 Google 的 Pixel 系列、三星的 Galaxy 系列，以及小米等厂商的大部分机型。

Android 动态照片本质上是在静态图片的末尾直接附加了一个视频文件，这个视频文件包含了音频与视频流。其中，视频文件的位置使用 `XMP` 元数据进行标记，这样在解析时可以快速找到视频文件的位置。这种格式的好处是可以在不改变原有图片的情况下，为图片添加动态效果。由于这一拓展并非图片格式的标准，因此在不支持的图片查看器上，这种图片只能被当作静态图片显示。

本工具可以用于这种动态照片的提取、修复、编辑与合成等操作。

## 安装预构建二进制

可以从 [Releases](https://github.com/wszqkzqk/live-photo-conv/releases) 页面下载预构建的二进制文件，支持 Arch Linux 与 Windows (MSYS2) 平台。

**请注意按照要求安装，不要解压后直接运行二进制文件，否则会导致找不到依赖库等问题。**如果遇到兼容性问题，请参考后续的[#构建脚本](#构建脚本)或[#手动构建](#手动构建)部分自行构建。

### Arch Linux

对于 Arch Linux 用户，请下载形如 `live-photo-conv-<版本号>-x86_64.pkg.tar.zst` 的文件，并使用 `pacman` 进行安装：

```bash
sudo pacman -U live-photo-conv-<版本号>-x86_64.pkg.tar.zst
```

### Windows (MSYS2)

对于 Windows 用户，我们提供了适用于 **MSYS2** 环境的安装包。请确保您已安装并更新了 [MSYS2](https://www.msys2.org/)。

1.  从发布页面下载形如 `mingw-w64-ucrt-x86_64-live-photo-conv-<版本号>-any.pkg.tar.zst` 的 Windows 安装包。
2.  打开 MSYS2 终端（UCRT64 环境）。
3.  使用 `pacman` 安装该包：

```bash
pacman -U mingw-w64-ucrt-x86_64-live-photo-conv-<版本号>-any.pkg.tar.zst
```

## 构建脚本

本项目提供 Arch Linux 与 Windows (MSYS2) 环境下的构建脚本。

### Arch Linux

Arch Linux 可以直接从 AUR 安装，例如使用 AUR 助手 `paru`：

```bash
paru -S live-photo-conv
```

也可以手动克隆 AUR 仓库并构建、安装：

```bash
git clone https://aur.archlinux.org/live-photo-conv.git
cd live-photo-conv
makepkg -si
```

### Windows (MSYS2)

Windows (MSYS2) 可以使用提供的 [`PKGBUILD`](https://gist.github.com/wszqkzqk/052a48feb5b84a469ee43231df91dc9d) 构建，例如在 MSYS2 UCRT64 环境的 `bash` 下执行以下命令：

```bash
mkdir live-photo-conv
cd live-photo-conv
wget https://gist.githubusercontent.com/wszqkzqk/052a48feb5b84a469ee43231df91dc9d/raw/PKGBUILD
makepkg-mingw -si
```

## 手动构建

### 依赖

* 构建依赖
  * Meson
  * Vala
  * GExiv2
  * GStreamer (可选，用于从附加视频导出图片，如果没有则使用FFmpeg命令来实现)
    * `gstreamer`
    * `gst-plugins-base-libs`
  * gdk-pixbuf2 (可选，用于从附加视频导出图片，如果没有则使用FFmpeg命令来实现)
  * gobject-introspection (可选，用于生成GObject Introspection信息)
* 运行依赖
  * GLib
    * GObject
    * GIO
  * GExiv2
  * GStreamer （在针对GStreamer构建时需要）
    * `gstreamer`
    * `gst-plugins-base-libs`
    * `gst-plugins-good`
    * `gst-plugins-bad`
    * `gst-plugin-va` （可选，用于硬件加速）
  * gdk-pixbuf2 （在针对GStreamer构建时需要）
    * `gdk-pixbuf2`
    * 如果想要支持更多导出格式，可以安装可选依赖，例如：
      * `libavif`: .avif
      * `libheif`: .heif, .heic, and .avif
      * `libjxl`: .jxl
      * `webp-pixbuf-loader`: .webp
  * FFmpeg （可选，在没有针对GStreamer构建且需要从附加视频导出图片时需要）

例如，在Arch Linux上安装依赖：

```bash
sudo pacman -S --needed glib2 libgexiv2 meson vala gstreamer gst-plugins-base-libs gdk-pixbuf2 gobject-introspection gst-plugins-good gst-plugins-bad gst-plugin-va
```

在Debian/Ubuntu上安装依赖：

```bash
sudo apt install build-essential meson valac libgexiv2-dev libglib2.0-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgdk-pixbuf-2.0-dev gobject-introspection libgirepository1.0-dev gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-vaapi
```

在Windows的MSYS2（UCRT64）环境上安装依赖：

```bash
pacman -S --needed mingw-w64-ucrt-x86_64-glib2 mingw-w64-ucrt-x86_64-cc mingw-w64-ucrt-x86_64-gexiv2 mingw-w64-ucrt-x86_64-meson mingw-w64-ucrt-x86_64-vala mingw-w64-ucrt-x86_64-gstreamer mingw-w64-ucrt-x86_64-gst-plugins-base mingw-w64-ucrt-x86_64-gdk-pixbuf2 mingw-w64-ucrt-x86_64-gobject-introspection mingw-w64-ucrt-x86_64-gst-plugins-good mingw-w64-ucrt-x86_64-gst-plugins-bad
```

### 编译

使用 Meson 和 Ninja 构建项目，使用 Meson 配置构建时默认自动检测是否支持 GStreamer 与是否可以生成GObject Introspection 信息。

Meson 构建选项：

* `gst`
  * 是否启用 GStreamer
  * 可选值为 `auto`、`enabled`、`disabled`，默认为 `auto`
* `gir`
  * 是否生成 GObject Introspection 信息
  * 可选值为 `auto`、`enabled`、`disabled`，默认为 `auto`
* `docs`
  * 是否在 GObject Introspection 信息中生成文档
  * 可选值为 `auto`、`enabled`、`disabled`，默认为 `auto`

首先需要克隆项目并进入项目顶级目录，后续给出的参考命令均需要在**项目顶级目录**下执行：

```bash
git clone https://github.com/wszqkzqk/live-photo-conv.git
cd live-photo-conv
```

可以通过以下命令配置构建：

```bash
meson setup builddir --buildtype=release
```

可以使用 Meson 构建选项配置构建，例如，如果不想生成 GObject Introspection 信息，可以使用以下命令：

```bash
meson setup builddir --buildtype=release -D gir=disabled
```

然后编译项目：

```bash
meson compile -C builddir
```

安装项目：

```bash
meson install -C builddir
```

## 使用

为了方便常见操作，此项目提供了三个简化的命令行工具，它们是 `live-photo-conv` 的符号链接，但提供了更简洁、专注于特定任务的命令行选项：

*   `live-photo-make`: 用于从图片和视频创建动态照片。
*   `live-photo-extract`: 用于从动态照片中提取图片、视频和视频帧。
*   `live-photo-repair`: 用于修复损坏的动态照片。

对于需要所有功能的复杂场景，可以直接使用 `live-photo-conv` 这一功能更全面的命令。

此外，为了解决 Android 设备上动态照片的兼容性问题，本项目还提供了 `copy-img-meta` 工具，用于复制图片的元数据，[满足手机厂商额外的要求](#android-手机厂商的分裂无法识别动态照片)。

### `live-photo-make`

从图片和视频创建动态照片。

#### 命令行选项

```
Usage:
  live-photo-make [OPTION…] - Make Live Photos from image and video files

Help Options:
  -h, --help            Show help options

Application Options:
  --version             Display version number
  --color=LEVEL         Color level of log, 0 for no color, 1 for auto, 2 for always, defaults to 1
  -i, --image=PATH      The path to the main static image file
  -m, --video=PATH      The path to the video file (required)
  -o, --output=PATH     The output live photo file path
  --export-metadata     Export metadata (default)
  --drop-metadata       Do not export metadata
  --use-ffmpeg          Use FFmpeg to extract instead of GStreamer
  --use-gst             Use GStreamer to extract instead of FFmpeg (default)
```

#### 示例

创建动态照片：

```bash
live-photo-make -i /path/to/image.jpg -m /path/to/video.mp4 -o /path/to/output.jpg
```

将视频直接转化为动态照片：

```bash
live-photo-make --video /path/to/video.mp4 --output /path/to/output.jpg
```

### `live-photo-extract`

从动态照片中提取图片、视频和视频帧。

#### 命令行选项

```
Usage:
  live-photo-extract [OPTION…] - Extract images and videos from Live Photos

Help Options:
  -h, --help                  Show help options

Application Options:
  --version                   Display version number
  --color=LEVEL               Color level of log, 0 for no color, 1 for auto, 2 for always, defaults to 1
  -p, --live-photo=PATH       The live photo file to extract (required)
  -d, --dest-dir=PATH         The destination directory to export
  -i, --image=PATH            The path to export the main image
  -m, --video=PATH            The path to export the video
  --export-metadata           Export metadata (default)
  --drop-metadata             Do not export metadata
  --frame-to-photos           Export every frame of the video as photos
  -f, --img-format=FORMAT     The format of the image exported from video
  -T, --threads=NUM           Number of threads to use for extracting, 0 for auto
  --use-ffmpeg                Use FFmpeg to extract instead of GStreamer
  --use-gst                   Use GStreamer to extract instead of FFmpeg (default)
```

#### 示例

提取动态照片：

```bash
live-photo-extract --live-photo /path/to/live_photo.jpg --dest-dir /path/to/dest
```

提取动态照片并将视频逐帧导出为图片：

```bash
live-photo-extract -p /path/to/live_photo.jpg -d /path/to/dest --frame-to-photos -f avif
```

### `live-photo-repair`

修复损坏的动态照片。

#### 命令行选项

```
Usage:
  live-photo-repair [OPTION…] - Repair Live Photos with missing or corrupted XMP metadata

Help Options:
  -h, --help                Show help options

Application Options:
  --version                 Display version number
  --color=LEVEL             Color level of log, 0 for no color, 1 for auto, 2 for always, defaults to 1
  -p, --live-photo=PATH     The live photo file to repair (required)
  -f, --force               Force to update video offset in XMP metadata and repair
  -s, --video-size=SIZE     Force repair with the specified video size
```

#### 示例

修复动态照片：

```bash
live-photo-repair -p /path/to/live_photo.jpg
```

### `live-photo-conv` (通用命令)

`live-photo-conv` 是一个功能全面的工具，整合了创建、提取和修复动态照片的所有功能。当简化的命令无法满足需求时，可以使用此命令。

#### 命令行选项

```
Usage:
  live-photo-conv [OPTION…] - Extract, Repair or Make Live Photos

Help Options:
  -h, --help                        Show help options

Application Options:
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
  --drop-metadata                   Do not export metadata
  --frame-to-photos                 Export every frame of a live photo's video as a photo
  -f, --img-format=FORMAT           The format of the image exported from video
  --minimal                         Minimal metadata export, ignore unspecified exports
  -T, --threads=NUM                 Number of threads to use for extracting, 0 for auto (not work in FFmpeg mode)
  --use-ffmpeg                      Use FFmpeg to extract instead of GStreamer
  --use-gst                         Use GStreamer to extract instead of FFmpeg (default)
```

运行 `live-photo-conv --help` 查看所有命令行选项。（如果没有启用GStreamer支持，`--use-ffmpeg`与`--use-gst`选项将不可用）

#### 示例

使用 `live-photo-conv` 的操作与简化命令类似，但需要明确指定操作模式（例如 `--make`, `--extract`, `--repair`）。

创建动态照片：

```bash
live-photo-conv --make --image /path/to/image.jpg --video /path/to/video.mp4 --live-photo /path/to/output.jpg
```

提取动态照片：

```bash
live-photo-conv --extract --live-photo /path/to/live_photo.jpg --dest-dir /path/to/dest
```

也可以通过URI指定文件：

```bash
live-photo-conv --make --image file:///path/to/image.jpg --video file:///path/to/video.mp4 --live-photo file:///path/to/output.jpg
```

修复动态照片：

```bash
live-photo-conv --repair --live-photo /path/to/live_photo.jpg
```

### `copy-img-meta`

#### 命令行选项

```
Usage:
  copy-img-meta [OPTION…] <exif-source-img> <dest-img> - Copy the metadata from one image to another

Help Options:
  -h, --help         Show help options

Application Options:
  -v, --version      Display version number
  --color=LEVEL      Color level of log, 0 for no color, 1 for auto, 2 for always, defaults to 1
  --exclude-exif     Do not copy EXIF data
  --with-exif        Copy EXIF data (default)
  --exclude-xmp      Do not copy XMP data
  --with-xmp         Copy XMP data (default)
  --exclude-iptc     Do not copy IPTC data
  --with-iptc        Copy IPTC data (default)
```

请运行 `copy-img-meta --help` 查看所有命令行选项。

#### 示例

从一张图片复制所有元数据到另一张图片：

```bash
copy-img-meta /path/to/exif-source.jpg /path/to/dest.webp
```

选择不复制某些元数据：

```bash
copy-img-meta --exclude-xmp --exclude-iptc /path/to/exif-source.jpg /path/to/dest.webp
```

### `liblivephototools`

* **警告：** 该库的API可能会随着版本的更新而发生变化。

`liblivephototools` 是一个用于创建和提取动态照片以及从内嵌视频中导出帧的库。它可以在支持 **GObject Introspection** 的**任何**语言中使用，例如 C、Vala、Rust、C++、Python 等。

#### 示例

以 Python 为例，确保已经安装了 `python-gobject` 包，然后可以通过以下代码导入库：

```python
import gi
gi.require_version('LivePhotoTools', '0.4') # 请根据实际版本号调整
from gi.repository import LivePhotoTools
```

使用示例：

```python
# 加载动态照片
livephoto = LivePhotoTools.LivePhotoGst.new("MVIMG_20241104_164717.jpg")
# 从动态照片中提取静态图像
livephoto.export_main_image()
# 从动态照片中提取视频
livephoto.export_video()
# 从内嵌视频中导出帧
livephoto.split_images_from_video(None, None, 0)
```

```python
# 创建动态照片
livemaker=LivePhotoTools.LiveMakerGst.new('VID_20241104_164717.mp4', 'IMG_20241104_164717.jpg')
# 导出
livemaker.export()
```

## 许可证

该项目使用 LGPL-2.1-or-later 许可证。详细信息请参阅 [`COPYING`](COPYING) 文件。

## FAQ

### 由嵌入视频导出图片：用 FFmpeg 还是用 GStreamer？

如果在构建时启用了GStreamer支持，那么默认将使用GStreamer来从嵌入视频中导出图片。否则，程序将直接尝试通过命令的方式创建FFmpeg子进程来导出图片。在启用了GStreamer支持的情况下，也可以通过`--use-ffmpeg`选项来使用FFmpeg。

使用GStreamer与FFmpeg导出谁更快往往并不一定。笔者构建的GStreamer视频导出图片工具的编码是并行的，可以通过调整`-T`/`--threads`选项来控制线程数。但是目前笔者没有将GStreamer的解码部分优化得很好，每次得到帧都进行了强制的颜色空间转化（[`gdk-pixbuf2`的限制](https://docs.gtk.org/gdk-pixbuf/property.Pixbuf.colorspace.html)），这也可能会引入性能损耗。因此，目前综合来看：

* 所选的图片编码较慢时，GStreamer导出图片更快
* 所选的图片编码较快时，FFmpeg导出图片更快

### Windows 下的路径编码：无法向包含非 ASCII 字符的路径读取或写入元数据

由于 Exiv2 的限制与 GExiv2 绑定的不完善，目前无法在 Windows 下向包含非 ASCII 字符的路径读取或写入元数据。

### Android 手机厂商的分裂：无法识别动态照片

由于 Android 手机厂商的分裂，不同厂商还可以需要动态照片中有自己的“私货”元数据才能识别动态照片。可能直接使用本工具生成的动态照片在某些手机上无法识别。

解决方案：

* 使用对应厂商的手机拍摄一张普通照片
* 使用 `copy-img-meta --exclude-xmp <source_image> <dest_image>` 将这张照片的元数据复制到生成的动态照片上
* 如果在手机上发现能识别但无法播放，使用 `live-photo-conv` 工具修复动态照片
  * 例如，使用 `live-photo-conv --repair -p /path/to/live_photo.jpg`
  * 或者强制修复 `live-photo-conv --force-repair -p /path/to/live_photo.jpg`
  * 极少数情况下如果仍然无法修复，可以尝试指定嵌入视频大小 `live-photo-conv --repair-with-video-size=SIZE -p /path/to/live_photo.jpg` （一般情况下不需要）

也可以事先先将元数据复制到用来制作动态照片的普通照片上，然后再使用 `live-photo-conv` 工具创建动态照片（推荐）：

```bash
copy-img-meta --exclude-xmp /path/to/source.jpg /path/to/dest.jpg
live-photo-conv --make --image /path/to/dest.jpg --video /path/to/video.mp4 --live-photo /path/to/output.jpg
```

这样可以一次性得到可以在对应品牌的手机上正常识别的动态照片。

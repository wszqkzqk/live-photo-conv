# Live Photo Converter

* [English Version](README.md)

Live Photo Converter 是一个用于处理动态照片的跨平台的工具。它可以将静态图像和视频合成为动态照片，直接将视频转化为动态照片，修复受损的动态照片，或者从动态照片中提取静态图像和视频，还可以将视频的每一帧导出为图片。

## 功能

- `live-photo-conv`
  - 创建动态照片
  - 从动态照片中提取静态图像和视频
  - 修复因为缺失 XMP 元数据而无法解析的动态照片
  - 导出视频的每一帧为图片
  - 支持导出元数据
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

## 构建脚本

本项目提供 Arch Linux 与 Windows (MSYS2) 环境下的构建脚本。

#### Arch Linux

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

#### Windows (MSYS2)

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
sudo pacman -S --needed glib2 libgexiv2 meson vala gstreamer gst-plugins-base-libs gdk-pixbuf2 gobject-introspection gst-plugins-good gst-plugins-bad
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

### `live-photo-conv`

#### 命令行选项

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

运行 `live-photo-conv --help` 查看所有命令行选项。（如果没有启用GStreamer支持，`--use-ffmpeg`与`--use-gst`选项将不可用）

#### 示例

创建动态照片：

```bash
live-photo-conv --make --image /path/to/image.jpg --video /path/to/video.mp4 --live-photo /path/to/output.jpg
```

将视频直接转化为动态照片：

```bash
live-photo-conv --make --video /path/to/video.mp4 --live-photo /path/to/output.jpg
```

提取动态照片：

```bash
live-photo-conv --extract --live-photo /path/to/live_photo.jpg --dest-dir /path/to/dest --frame-to-photos --img-format avif
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
gi.require_version('LivePhotoTools', '0.3') # 请根据实际版本号调整
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
livephoto.splites_images_from_video(None, None, 0)
```

```python
# 创建动态照片
livemaker=LivePhotoTools.LiveMakerGst.new('VID_20241104_164717.mp4', 'IMG_20241104_164717.jpg')
# 导出
livemaker.export()
```

#### 已知问题

Vala[将在0.58支持将Vala代码中的注释文档导出到GObject Introspection](https://gitlab.gnome.org/GNOME/vala/-/merge_requests/303)中，因此如果使用0.58之前的Vala版本构建，会导致GObject Introspection信息中没有文档。

## 由嵌入视频导出图片：用FFmpeg还是用GStreamer？

如果在构建时启用了GStreamer支持，那么默认将使用GStreamer来从嵌入视频中导出图片。否则，程序将直接尝试通过命令的方式创建FFmpeg子进程来导出图片。在启用了GStreamer支持的情况下，也可以通过`--use-ffmpeg`选项来使用FFmpeg。

使用GStreamer与FFmpeg导出谁更快往往并不一定。笔者构建的GStreamer视频导出图片工具的编码是并行的，可以通过调整`-T`/`--threads`选项来控制线程数。但是目前笔者没有将GStreamer的解码部分优化得很好，每次得到帧都进行了强制的颜色空间转化（[`gdk-pixbuf2`的限制](https://docs.gtk.org/gdk-pixbuf/property.Pixbuf.colorspace.html)），这也可能会引入性能损耗。因此，目前综合来看：

* 所选的图片编码较慢时，GStreamer导出图片更快
* 所选的图片编码较快时，FFmpeg导出图片更快

## 许可证

该项目使用 LGPL-2.1-or-later 许可证。详细信息请参阅 [`COPYING`](COPYING) 文件。

## 已知问题

由于 Exiv2 的限制与 GExiv2 绑定的不完善，目前无法在 Windows 下向包含非 ASCII 字符的路径读取或写入元数据。

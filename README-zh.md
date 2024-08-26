# Motion Photo Converter

* [English Version](README.md)

Motion Photo Converter 是一个用于处理动态照片的工具。它可以将静态图像和视频合成为动态照片，或者从动态照片中提取静态图像和视频，还可以将视频的每一帧导出为图片。

## [背景](https://wszqkzqk.github.io/2024/08/01/%E8%A7%A3%E6%9E%90Android%E7%9A%84%E5%8A%A8%E6%80%81%E7%85%A7%E7%89%87/)

Android 的动态照片是一种逐渐普及的媒体文件格式，它可以将包含音频的视频与静态图片结合在一起，形成一个动态的照片。这种照片已经在多种机型上得到了支持，例如 Google 的 Pixel 系列、三星的 Galaxy 系列，以及小米等厂商的大部分机型。

Android 动态照片本质上是在静态图片的末尾直接附加了一个视频文件，这个视频文件包含了音频与视频流。其中，视频文件的位置使用 `XMP` 元数据进行标记，这样在解析时可以快速找到视频文件的位置。这种格式的好处是可以在不改变原有图片的情况下，为图片添加动态效果。由于这一拓展并非图片格式的标准，因此在不支持的图片查看器上，这种图片只能被当作静态图片显示。

本工具可以用于这种动态照片的提取、编辑与合成等操作。

## 功能

- 创建动态照片
- 从动态照片中提取静态图像和视频
- 导出视频的每一帧为图片
- 支持导出元数据

## 构建

### 依赖

* 构建依赖
  * Meson
  * Vala
  * GStreamer (可选，用于从附加视频导出图片，如果没有则使用FFmpeg命令来实现)
    * `gstreamer`
    * `gst-plugins-base-libs`
  * gdk-pixbuf2 (可选，用于从附加视频导出图片，如果没有则使用FFmpeg命令来实现)
* 运行依赖
  * GLib
    * GObject
    * GIO
  * GExiv2
  * GStreamer （在针对GStreamer构建时需要）
    * `gstreamer`
    * `gst-plugins-base-libs`
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
sudo pacman -S --needed glib2 gexiv2 meson vala gstreamer gst-plugins-base-libs gdk-pixbuf2
```

在MSYS2（UCRT64环境）上安装依赖：

```bash
pacman -S --needed mingw-w64-ucrt-x86_64-glib2 mingw-w64-ucrt-x86_64-gexiv2 mingw-w64-ucrt-x86_64-meson mingw-w64-ucrt-x86_64-vala mingw-w64-ucrt-x86_64-gstreamer mingw-w64-ucrt-x86_64-gst-plugins-base-libs mingw-w64-ucrt-x86_64-gdk-pixbuf2
```

### 编译

使用Meson和Ninja构建项目，使用Meson配置构建时默认自动检测是否支持GStreamer（等价于`-Dgst=auto`）：

```bash
meson setup builddir --buildtype=release
```

如果要强制使用GStreamer，可以使用`-Dgst=enabled`：

```bash
meson setup builddir --buildtype=release -Dgst=enabled
```

如果要强制禁用GStreamer，可以使用`-Dgst=disabled`：

```bash
meson setup builddir --buildtype=release -Dgst=disabled
```

然后编译项目：

```bash
meson compile -C builddir
```

## 使用

### 命令行选项

运行 `motion-photo-conv --help` 查看所有命令行选项。

### 示例

创建动态照片：

```bash
motion-photo-conv --make --image /path/to/image.jpg --video /path/to/video.mp4 --motion-photo /path/to/output.jpg
```

提取动态照片：

```bash
motion-photo-conv --extract --motion-photo /path/to/motion_photo.jpg --dest-dir /path/to/dest --frame-to-photos --img-format avif
```

也可以通过URI指定文件：

```bash
motion-photo-conv --make --image file:///path/to/image.jpg --video file:///path/to/video.mp4 --motion-photo file:///path/to/output.jpg
```

## 由嵌入视频导出图片：用FFmpeg还是用GStreamer？

如果在构建时启用了GStreamer支持，那么默认将使用GStreamer来从嵌入视频中导出图片。否则，程序将直接尝试通过命令的方式创建FFmpeg子进程来导出图片。在启用了GStreamer支持的情况下，也可以通过`--use-ffmpeg`选项来使用FFmpeg。

使用GStreamer与FFmpeg导出谁更快往往并不一定。笔者构建的GStreamer视频导出图片工具的编码是并行的，可以通过调整`-j`/`--threads`选项来控制线程数。但是目前笔者没有将GStreamer的解码部分优化得很好，每次得到帧都进行了强制的颜色空间转化，这也可能会引入性能损耗。因此，目前综合来看：

* 所选的图片编码较慢时，GStreamer导出图片更快
* 所选的图片编码较快时，FFmpeg导出图片更快

## 许可证

该项目使用 LGPL-2.1-or-later 许可证。详细信息请参阅 [`COPYING`](COPYING) 文件。

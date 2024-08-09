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

* 运行依赖
  * GLib
    * GObject
    * GIO
  * GExiv2
  * FFmpeg
* 构建依赖
  * Meson
  * Vala

例如，在Arch Linux上安装依赖：

```bash
sudo pacman -S --needed glib2 gexiv2 ffmpeg meson vala
```

在MSYS2（UCRT64环境）上安装依赖：

```bash
pacman -S --needed mingw-w64-ucrt-x86_64-glib2 mingw-w64-ucrt-x86_64-gexiv2 mingw-w64-ucrt-x86_64-ffmpeg mingw-w64-ucrt-x86_64-meson mingw-w64-ucrt-x86_64-vala
```

### 编译

使用 Meson 和 Ninja 构建项目：

```bash
meson setup builddir --buildtype=release
meson compile -C builddir
```

## 使用

### 命令行选项

- `-h, --help`：显示帮助信息
- `-v, --version`：显示版本号
- `-g, --make`：创建动态照片
- `-e, --extract`：提取动态照片（默认）
- `-i, --image PATH`：静态图像文件的路径
- `-m, --video PATH`：视频文件的路径
- `-p, --motion-photo PATH`：动态照片文件的目标路径。如果在 `make` 模式下未提供，将根据静态图像文件生成默认路径
- `-d, --dest-dir PATH`：导出目标目录
- `--export-metadata`：导出元数据（默认）
- `--no-export-metadata`：不导出元数据
- `--frame-to-photos`：将动态照片的视频的每一帧导出为图片
- `-f, --img-format FORMAT`：从视频导出的图片格式
- `--color LEVEL`：颜色级别，0 表示无颜色，1 表示自动，2 表示总是，默认为 1

### 示例

创建动态照片：

```sh
motion-photo-conv --make --image /path/to/image.jpg --video /path/to/video.mp4 --motion-photo /path/to/output.jpg
```

提取动态照片：

```sh
motion-photo-conv --extract --motion-photo /path/to/motion_photo.jpg --dest-dir /path/to/dest --frame-to-photos --img-format avif
```

## 许可证

该项目使用 LGPL-2.1-or-later 许可证。详细信息请参阅 [`COPYING`](COPYING) 文件。

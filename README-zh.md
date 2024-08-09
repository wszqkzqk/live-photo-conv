# Motion Photo Converter

* [English Version](README.md)

Motion Photo Converter 是一个用于处理运动照片的工具。它可以将静态图像和视频合成为运动照片，或者从运动照片中提取静态图像和视频，还可以将视频的每一帧导出为图片。

## 功能

- 创建运动照片
- 从运动照片中提取静态图像和视频
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
- `-g, --make`：创建运动照片
- `-e, --extract`：提取运动照片（默认）
- `-i, --image PATH`：静态图像文件的路径
- `-m, --video PATH`：视频文件的路径
- `-p, --motion-photo PATH`：运动照片文件的目标路径。如果在 `make` 模式下未提供，将根据静态图像文件生成默认路径
- `-d, --dest-dir PATH`：导出目标目录
- `--export-metadata`：导出元数据（默认）
- `--no-export-metadata`：不导出元数据
- `--frame-to-photos`：将运动照片的视频的每一帧导出为图片
- `-f, --img-format FORMAT`：从视频导出的图片格式
- `--color LEVEL`：颜色级别，0 表示无颜色，1 表示自动，2 表示总是，默认为 1

### 示例

创建运动照片：

```sh
motion-photo-conv --make --image /path/to/image.jpg --video /path/to/video.mp4 --motion-photo /path/to/output.jpg
```

提取运动照片：

```sh
motion-photo-conv --extract --motion-photo /path/to/motion_photo.jpg --dest-dir /path/to/dest --frame-to-photos --img-format avif
```

## 许可证

该项目使用 LGPL-2.1-or-later 许可证。详细信息请参阅 [`COPYING`](COPYING) 文件。

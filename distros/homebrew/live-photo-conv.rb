class LivePhotoConv < Formula
  desc "Cross-platform tool to process live photos of Google Android"
  homepage "https://github.com/wszqkzqk/live-photo-conv"
  license "LGPL-2.1-or-later"
  head "https://github.com/wszqkzqk/live-photo-conv.git", branch: "main"

  depends_on "gettext" => :build
  depends_on "help2man" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "vala" => :build
  depends_on "adwaita-icon-theme"
  depends_on "gexiv2"
  depends_on "gobject-introspection"
  depends_on "gstreamer"
  depends_on "gtk4"
  depends_on "libadwaita"

  def install
    system "meson", "setup", "build", *std_meson_args
    system "meson", "compile", "-C", "build"
    system "meson", "install", "-C", "build"
  end

  test do
    system bin/"live-photo-conv", "--version"
    system bin/"live-photo-make", "--version"
    system bin/"live-photo-extract", "--version"
    system bin/"live-photo-repair", "--version"
    system bin/"copy-img-meta", "--version"
  end
end

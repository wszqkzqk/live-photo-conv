class LivePhotoConv < Formula
  desc "Cross-platform tool to process live photos of Google Android"
  homepage "https://github.com/wszqkzqk/live-photo-conv"
  license "LGPL-2.1-or-later"
  head "https://github.com/wszqkzqk/live-photo-conv.git", branch: "main", using: :git

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "vala" => :build
  depends_on "gobject-introspection" => :build
  depends_on "help2man" => :build

  depends_on "adwaita-icon-theme"
  depends_on "gdk-pixbuf"
  depends_on "gexiv2"
  depends_on "glib"
  depends_on "gstreamer"
  depends_on "gtk4"
  depends_on "libadwaita"

  def install
    system "meson", "setup", "build", *std_meson_args
    system "meson", "compile", "-C", "build"
    system "meson", "install", "-C", "build"
  end

  test do
    assert_match "Live Photo Converter", shell_output("#{bin}/live-photo-conv --version 2>&1")
    assert_predicate bin/"live-photo-conv-gtk", :exist?
  end
end

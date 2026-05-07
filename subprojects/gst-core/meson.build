project('gst-core', 'c')

gst_prefix = '/home/runner/android-deps'

gst_dep = declare_dependency(
  include_directories: include_directories(
    gst_prefix / 'include' / 'gstreamer-1.0',
    gst_prefix / 'lib' / 'glib-2.0' / 'include',
    gst_prefix / 'include',
  ),
  link_args: ['-L' + gst_prefix / 'lib', '-lgstreamer-1.0'],
)

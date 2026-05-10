project('gst-core', 'c')

# Resolve Android pre-built deps prefix from the environment instead of
# hard-coding a CI-specific path. Allows local Android builds and different
# CI runners to work without editing this file.
gst_prefix = run_command('sh', '-c', 'echo "$ANDROID_DEPS_PREFIX"', check: false).stdout().strip()
if gst_prefix == ''
  error('ANDROID_DEPS_PREFIX environment variable is not set. Required for Android GStreamer fallback.')
endif

gst_dep = declare_dependency(
  include_directories: include_directories(
    gst_prefix / 'include' / 'gstreamer-1.0',
    gst_prefix / 'lib' / 'glib-2.0' / 'include',
    gst_prefix / 'include',
  ),
  link_args: ['-L' + gst_prefix / 'lib', '-lgstreamer-1.0'],
)

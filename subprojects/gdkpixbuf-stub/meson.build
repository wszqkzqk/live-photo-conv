project('gdk-pixbuf', 'c', version: '2.42.12')

# Resolve Android pre-built deps prefix from the environment instead of
# assuming a fixed path.
deps_prefix = run_command('sh', '-c', 'echo "$ANDROID_DEPS_PREFIX"', check: false).stdout().strip()
if deps_prefix == ''
  error('ANDROID_DEPS_PREFIX environment variable is not set. Required for Android gdk-pixbuf fallback.')
endif

gdk_pixbuf_dep = declare_dependency(
  include_directories: include_directories(deps_prefix / 'include' / 'gdk-pixbuf-2.0'),
  link_args: ['-L' + deps_prefix / 'lib', '-lgdk_pixbuf-2.0'],
)

gdk_pixbuf_2_0_dep = gdk_pixbuf_dep

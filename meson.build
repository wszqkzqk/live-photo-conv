project('live-photo-conv', ['c', 'vala'],
          version: '0.40.3',
    meson_version: '>= 1.4',
)

# Library versioning
lib_api_version = '0.4'  # GIR version / API version
lib_soversion = '0'      # SONAME version / ABI version

# Platform detection — single source of truth, used throughout the build.
# Pattern borrowed from libadwaita: define once, reference everywhere.
target_system = host_machine.system()
is_windows = target_system == 'windows'
is_darwin = target_system == 'darwin'
is_android = target_system == 'android'
is_freedesktop = not is_windows and not is_darwin and not is_android  # Linux, BSD, etc.

if is_windows
  add_project_arguments('-D', 'WINDOWS', language: 'vala')
endif
if is_android
  add_project_arguments('-D', 'ANDROID', language: 'vala')
  # GExiv2 VAPI files may be pre-generated for Android builds and placed in
  # vapi/ (e.g. by android/build-exiv2-android.sh). Only add the vapidir
  # when the directory actually exists so local non-Android builds don't fail.
  vapi_dir = meson.project_source_root() / 'vapi'
  if fs.is_dir(vapi_dir)
    add_project_arguments('--vapidir', vapi_dir, language: 'vala')
  endif
endif

# Core dependencies (always required)
basic_deps = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
  dependency('gmodule-2.0'),
  dependency('gexiv2', fallback: ['gexiv2', 'libgexiv2']),
]
lib_deps = basic_deps

# Optional GStreamer dependencies
# On Android, GStreamer is required (FFmpeg subprocess not available)
require_gst = get_option('gst')
if is_android
  require_gst = true
endif

# On Android, GStreamer and gdk-pixbuf are provided as pre-built libraries
# outside the normal pkg-config / wrap ecosystem. Use fallback subprojects
# that resolve them via the ANDROID_DEPS_PREFIX environment variable.
gst_fallback = is_android ? ['gst-core', 'gst_dep'] : []
gst_app_fallback = is_android ? ['gst-app', 'gst_app_dep'] : []
gdkpixbuf_fallback = is_android ? ['gdkpixbuf-stub', 'gdk_pixbuf_dep'] : []

gst = dependency('gstreamer-1.0', required: require_gst, fallback: gst_fallback)
gst_app = dependency('gstreamer-app-1.0', required: require_gst, fallback: gst_app_fallback)
gdk_pixbuf = dependency('gdk-pixbuf-2.0', required: require_gst, fallback: gdkpixbuf_fallback)

# Optional GTK4/LibAdwaita GUI dependencies
# On Android, the GUI is the only supported interface — require it
require_gui = get_option('gui')
if is_android
  require_gui = true
endif

gtk4_dep = dependency('gtk4', required: require_gui)
libadwaita_dep = dependency('libadwaita-1', required: require_gui, fallback: is_android ? ['libadwaita', 'libadwaita_dep'] : [])
with_gui = gtk4_dep.found() and libadwaita_dep.found()
if is_android and not with_gui
  error('GTK4 and LibAdwaita are required for Android builds')
endif

with_gst = gst.found() and gst_app.found() and gdk_pixbuf.found()
if with_gst
  add_project_arguments('-D', 'ENABLE_GST', language: 'vala')
  lib_deps += [
    gst,
    gst_app,
    gdk_pixbuf
  ]
endif

# Other tool dependencies
fs = import('fs')
pkg = import('pkgconfig')
gnome = import('gnome')
i18n = import('i18n')
python = import('python').find_installation()

# i18n - must be defined before vala sources that use _()
add_project_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language: 'c')

# Optional tools
g_ir_compiler = find_program('g-ir-compiler', required: get_option('gir'))
help2man_prog = find_program('help2man', required: get_option('manpages'))
valadoc = find_program('valadoc', required: get_option('docs'))

#incdir = include_directories('include')

subdir('src')

subdir('po')

if with_gui and is_freedesktop
  gnome.post_install (
    gtk_update_icon_cache: true,
    update_desktop_database: true,
  )
endif

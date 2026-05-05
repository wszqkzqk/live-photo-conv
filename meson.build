project('live-photo-conv', ['c', 'vala'],
          version: '0.40.3',
    meson_version: '>= 1.4',
)

# Library versioning
lib_api_version = '0.4'  # GIR version / API version
lib_soversion = '0'      # SONAME version / ABI version

# Platform detection
is_windows = target_machine.system() == 'windows'
is_darwin = target_machine.system() == 'darwin'
is_android = target_machine.system() == 'android'
is_freedesktop = not is_windows and not is_darwin and not is_android  # Linux, BSD, etc.
if is_windows
  add_project_arguments('-D', 'WINDOWS', language: 'vala')
endif
if is_android
  add_project_arguments('-D', 'ANDROID', language: 'vala')
endif

# Dependencies
basic_deps = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
  dependency('gmodule-2.0'),
  dependency('gexiv2'),
]
# Dependencies for the library
lib_deps = basic_deps

# Optional GStreamer dependencies
# On Android, GStreamer is required (FFmpeg subprocess not available)
require_gst = get_option('gst')
if is_android
  require_gst = true
endif
gst = dependency('gstreamer-1.0', required: require_gst)
gst_app = dependency('gstreamer-app-1.0', required: require_gst)
gdk_pixbuf = dependency('gdk-pixbuf-2.0', required: require_gst)

# Optional GTK4/LibAdwaita GUI dependencies
# On Android, the GUI is the only supported interface — require it
require_gui = get_option('gui')
if is_android
  require_gui = true
endif
gtk4_dep = dependency('gtk4', required: require_gui)
libadwaita_dep = dependency('libadwaita-1', required: require_gui)
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

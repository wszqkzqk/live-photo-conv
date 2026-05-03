project('live-photo-conv', ['c', 'vala'],
          version: '0.4.7',
    meson_version: '>= 1.1',
)

# Library versioning
lib_api_version = '0.4'  # GIR version / API version
lib_soversion = '0'      # SONAME version / ABI version

# Windows-specific flags
is_windows = target_machine.system() == 'windows'
is_linux = target_machine.system() == 'linux'
if is_windows
  add_project_arguments('-D', 'WINDOWS', language: 'vala')
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
require_gst = get_option('gst')
gst = dependency('gstreamer-1.0', required: require_gst)
gst_app = dependency('gstreamer-app-1.0', required: require_gst)
gdk_pixbuf = dependency('gdk-pixbuf-2.0', required: require_gst)

# Optional GTK4/LibAdwaita GUI dependencies
require_gui = get_option('gui')
gtk4_dep = dependency('gtk4', required: require_gui)
libadwaita_dep = dependency('libadwaita-1', required: require_gui)
with_gui = gtk4_dep.found() and libadwaita_dep.found()

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
python = import('python').find_installation()

# Optional tools
g_ir_compiler = find_program('g-ir-compiler', required: get_option('gir'))
help2man_prog = find_program('help2man', required: get_option('manpages'))
valadoc = find_program('valadoc', required: get_option('docs'))

#incdir = include_directories('include')

subdir('src')

if with_gui and is_linux
  gnome.post_install (
    gtk_update_icon_cache: true,
    update_desktop_database: true,
  )
endif

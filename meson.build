project('live-photo-conv', ['c', 'vala'],
          version: '0.40.4',
          license: 'LGPL-2.1-or-later',
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

# Android: resolve extra dependencies via subprojects to ensure
# a single shared GLib across gexiv2, gstreamer and the app.
# This avoids the fatal "two GLib instances" runtime crash.
if is_android
  # Exiv2 (needed by gexiv2). Exiv2 already overrides its own dependency name.
  subproject('exiv2', default_options: [
      'app=disabled',
      'tests=disabled',
      'unitTests=disabled',
      'webready=disabled',
      'curl=disabled',
      'brotli=disabled',
      'nls=disabled',
      'bmff=enabled',
  ])

  # GExiv2 — introspection/vapi are disabled for cross-compilation.
  # Only pass options known to exist in both 0.14.x and 0.16.x.
  gexiv2_proj = subproject('gexiv2', default_options: [
      'introspection=false',
      'vapi=false',
      'tests=false',
      'gtk_doc=false',
  ])
  meson.override_dependency('gexiv2', gexiv2_proj.get_variable('libgexiv2'))

  # Make sure Vala can find the pre-generated VAPI for gexiv2.
  vapi_dir = meson.project_source_root() / 'vapi'
  add_project_arguments('--vapidir', vapi_dir, language: 'vala')
endif

# Dependencies
basic_deps = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
  dependency('gmodule-2.0'),
  dependency('gexiv2-0.16', 'gexiv2'),
]
# Dependencies for the library
lib_deps = basic_deps

# Optional GStreamer dependencies
# On Android, GStreamer is required (FFmpeg subprocess not available)
require_gst = get_option('gst')
if is_android
  require_gst = true
endif
gst = dependency('gstreamer-1.0', required: require_gst,
  fallback: ['gstreamer', 'gst_dep'])
gst_app = dependency('gstreamer-app-1.0', required: require_gst,
  fallback: ['gst-plugins-base', 'app_dep'])
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

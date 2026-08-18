project('live-photo-conv', ['c', 'vala'],
          version: '0.40.4',
          license: 'LGPL-2.1-or-later',
    meson_version: '>= 1.4',
)

# Library versioning
lib_api_version = '0.4'  # GIR version / API version
lib_soversion = '0'      # SONAME version / ABI version

vcs_version = meson.project_version()
git = find_program('git', required: false)
if git.found()
  git_desc = run_command(git, 'describe', '--tags', '--abbrev=12', '--dirty', check: false)
  if git_desc.returncode() == 0
    raw = git_desc.stdout().strip()
    if raw.startswith('v')
      raw = raw.substring(1)
    endif
    vcs_version = raw.replace('-', '.')
  endif
endif

# Platform-specific flags
is_windows = target_machine.system() == 'windows'
is_darwin = target_machine.system() == 'darwin'
is_android = target_machine.system() == 'android'
is_freedesktop = not is_windows and not is_darwin and not is_android  # Linux, BSD, etc.
if is_windows
  add_project_arguments('-D', 'WINDOWS', language: 'vala')
endif
if is_android
  if not meson.version().version_compare('>= 1.9')
    error('Android builds require meson >= 1.9, found ' + meson.version())
  endif
  add_project_arguments('-D', 'ANDROID', language: 'vala')
  # No GObject-Introspection in Android cross builds; use vendored VAPIs
  add_project_arguments('--vapidir', meson.project_source_root() / 'android' / 'vapi', language: 'vala')
  # Make statically linked FFmpeg NEON asm linkable into shared objects
  add_project_link_arguments('-Wl,-Bsymbolic', language: ['c', 'cpp'])
  # exiv2/gexiv2 need the C++ runtime; ship it in the APK
  libcpp = meson.get_external_property('sys_root') / 'usr' / 'lib' / (
    target_machine.cpu_family() + '-linux-android') / 'libc++_shared.so'
  install_data(libcpp, install_dir: get_option('libdir'), install_tag: 'runtime')
  # Consumed by pixiewood.xml via a build:// include
  configure_file(
    input: 'android/app.metainfo.xml.in',
    output: 'app.metainfo.xml',
    configuration: {'VERSION': vcs_version},
  )
endif

# Dependencies
basic_deps = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
  dependency('gmodule-2.0'),
]
if is_android
  # Not in pixiewood's wrap set; built from subprojects/gexiv2android.wrap.
  basic_deps += dependency('gexiv2', fallback: ['gexiv2android', 'libgexiv2'])
else
  basic_deps += dependency('gexiv2-0.16', 'gexiv2')
endif
# Dependencies for the library
lib_deps = basic_deps

# Optional GTK4/LibAdwaita GUI dependencies
# NOTE: must be resolved before gstreamer-full: the monorepo also calls
# subproject('gtk'), which would poison the global subproject cache.
require_gui = get_option('gui')
if is_android
  # On Android the GUI *is* the application
  require_gui = true
endif
gtk4_dep = dependency('gtk4', required: require_gui)
libadwaita_dep = dependency('libadwaita-1', required: require_gui)
with_gui = gtk4_dep.found() and libadwaita_dep.found()

# Optional GStreamer dependencies
require_gst = get_option('gst')
if is_android
  # Spawning external ffmpeg is not viable on Android; the in-process
  # GStreamer backend is mandatory, statically linked via gst-full.
  # gdk-pixbuf comes from pixiewood's <gdk-pixbuf/> dependency.
  require_gst = true
  gst = dependency('gstreamer-full-1.0', fallback: ['gstreamer-full', 'gst_full_dep'])
  gst_app = gst
  gdk_pixbuf = dependency('gdk-pixbuf-2.0')
else
  gst = dependency('gstreamer-1.0', required: require_gst)
  gst_app = dependency('gstreamer-app-1.0', required: require_gst)
  gdk_pixbuf = dependency('gdk-pixbuf-2.0', required: require_gst)
endif

# Vala package names for Android, where every GTK-stack dependency is a
# subproject and Meson cannot infer --pkg from it.
android_vala_args = []
android_gui_vala_args = []
if is_android
  foreach pkg : ['gio-2.0', 'gmodule-2.0', 'gexiv2',
                 'gstreamer-1.0', 'gstreamer-app-1.0', 'gdk-pixbuf-2.0']
    android_vala_args += ['--pkg', pkg]
  endforeach
  android_gui_vala_args = android_vala_args + ['--pkg', 'gtk4', '--pkg', 'libadwaita-1']
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

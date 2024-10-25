version_file = vcs_tag(
   command: ['git', 'describe', '--tags'],
     input: 'version.vala.in',
    output: 'version.vala',
)

basic_deps = [
  glib,
  gobject,
  gio,
  gmodule,
  gexiv2,
]

# Find GStreamer dependencies
require_gst = get_option('gst')
gst = dependency('gstreamer-1.0', required: require_gst)
gst_app = dependency('gstreamer-app-1.0', required: require_gst)
gdk_pixbuf = dependency('gdk-pixbuf-2.0', required: require_gst)

lib_sources = [
  'errordomains.vala',
  'livemaker.vala',
  'livephoto.vala',
  'livephotoffmpeg.vala',
  'main.vala',
  'reporter.vala',
  'utils.vala',
  version_file,
]

# Check if all GStreamer dependencies are found
if gst.found() and gst_app.found() and gdk_pixbuf.found()
  add_project_arguments('-D', 'ENABLE_GST', language: 'vala')

  basic_deps += [
    gst,
    gst_app,
    gdk_pixbuf
  ]

  lib_sources += [
    'livephotogst.vala',
    'sample2img.vala'
  ]
endif

g_ir_compiler = find_program('g-ir-compiler', required: get_option('gir'))
g_ir_version = '0.1'

if g_ir_compiler.found()
  liblivephototools = shared_library(
    'livephototools', lib_sources,
    vala_gir: 'livephototools-' + g_ir_version + '.gir',
    dependencies: basic_deps,
    include_directories: incdir,
    install: true,
    install_dir: [true, 'include/livephototools', true, true]
  )
else
  liblivephototools = shared_library(
    'livephototools', lib_sources,
    dependencies: basic_deps,
    include_directories: incdir,
    install: true,
    install_dir: [true, 'include/livephototools', true]
  )
endif

install_headers(
  ['../include/bindings.h'],
  subdir: 'livephototools',
)

pkg = import('pkgconfig')
pkg.generate(
  name: 'livephototools',
  filebase: 'livephototools',
  description: 'A library for live photo conversion',
  libraries: liblivephototools,
  version: meson.project_version(),
  subdirs: 'include/livephototools',
  requires: basic_deps,
)

executable('live-photo-conv',
  ['main.vala'],
  install: true,
  link_with: liblivephototools,
  dependencies: basic_deps,
  include_directories: incdir,
)

executable('copy-img-meta',
  ['copyimgmeta.vala'],
  install: true,
  link_with: liblivephototools,
  dependencies: basic_deps,
  include_directories: incdir,
)

if g_ir_compiler.found()
  custom_target('livephototools typelib',
    input: liblivephototools,
    output: 'livephototools-' + g_ir_version + '.typelib',
    depends: liblivephototools,
    command: [
      g_ir_compiler,
      '--shared-library',
      '@PLAINNAME@',
      '--output',
      '@OUTPUT@',
      join_paths(meson.current_build_dir(), 'livephototools-' + g_ir_version + '.gir')],
    install: true,
    install_dir: get_option('libdir') / 'girepository-1.0',
  )
endif

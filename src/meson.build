version_file = vcs_tag(
   command: meson.project_version(),
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

lib_common_sources = [
  'errordomains.vala',
  'livemaker.vala',
  'livemakerffmpeg.vala',
  'livephoto.vala',
  'livephotoffmpeg.vala',
  'main.vala',
  'platformbindings.c',
  'reporter.vala',
  'utils.vala',
]

lib_sources = lib_common_sources + [version_file]

# Check if all GStreamer dependencies are found
if gst.found() and gst_app.found() and gdk_pixbuf.found()
  add_project_arguments('-D', 'ENABLE_GST', language: 'vala')

  basic_deps += [
    gst,
    gst_app,
    gdk_pixbuf
  ]

  lib_sources += [
    'livemakergst.vala',
    'livephotogst.vala',
    'sample2img.vala'
  ]
endif

g_ir_compiler = find_program('g-ir-compiler', required: get_option('gir'))
lib_gi_name = 'LivePhotoTools'
lib_gi_version = '0.3'
lib_gi = 'LivePhotoTools-' + lib_gi_version
lib_gir = lib_gi + '.gir'
lib_typelib = lib_gi + '.typelib'

if g_ir_compiler.found()
  liblivephototools = shared_library(
    'livephototools', lib_sources,
    vala_gir: lib_gir,
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
  ['../include/platformbindings.h'],
  subdir: 'livephototools',
)

pkg = import('pkgconfig')
pkg.generate(
  name: 'LivePhotoTools',
  filebase: 'livephototools',
  description: 'A library for live photo conversion',
  libraries: liblivephototools,
  version: meson.project_version(),
  subdirs: 'include/livephototools',
  requires: basic_deps,
)

live_photo_conv_name = 'live-photo-conv'
live_photo_conv_bin = executable(live_photo_conv_name,
  ['main.vala'],
  install: true,
  link_with: liblivephototools,
  dependencies: basic_deps,
  include_directories: incdir,
)

copy_img_meta_name = 'copy-img-meta'
copy_img_meta_bin = executable(copy_img_meta_name,
  ['copyimgmeta.vala'],
  install: true,
  link_with: liblivephototools,
  dependencies: basic_deps,
  include_directories: incdir,
)

if g_ir_compiler.found()
  custom_target(lib_typelib,
    input: liblivephototools,
    output: lib_typelib,
    depends: liblivephototools,
    command: [
      g_ir_compiler,
      '--shared-library',
      '@PLAINNAME@',
      '--output',
      '@OUTPUT@',
      meson.current_build_dir() / lib_gir,
    ],
    install: true,
    install_dir: get_option('libdir') / 'girepository-1.0',
  )
endif

help2man_prog = find_program('help2man', required: get_option('manpages'))

if help2man_prog.found()
  custom_target('manpage-' + live_photo_conv_name,
    output : live_photo_conv_name + '.1',
    command : [
      help2man_prog,
      '-N',
      '-o',
      '@OUTPUT@',
      live_photo_conv_bin,
      '--no-discard-stderr',
    ],
    install : true,
    install_dir : get_option('mandir') / 'man1',
  )

  custom_target('manpage-' + copy_img_meta_name,
    output : copy_img_meta_name + '.1',
    command : [
      help2man_prog,
      '-N',
      '-o',
      '@OUTPUT@',
      copy_img_meta_bin,
      '--no-discard-stderr',
    ],
    install : true,
    install_dir : get_option('mandir') / 'man1',
  )
endif

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

liblivephototools = shared_library('livephototools', lib_sources,
  dependencies: basic_deps,
  include_directories: incdir,
  install: true,
  install_dir: [true, true, true]
)

executable('live-photo-conv',
  ['main.vala'],
  install: true,
  link_with: liblivephototools,
  dependencies: basic_deps,
  include_directories: incdir,
)

executable('copy-exif',
  ['copyexif.vala'],
  install: true,
  link_with: liblivephototools,
  dependencies: basic_deps,
  include_directories: incdir,
)

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

livephotoconv_sources = [
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

  livephotoconv_sources += [
    'livephotogst.vala',
    'sample2img.vala'
  ]
endif

executable('live-photo-conv', livephotoconv_sources,
  dependencies: basic_deps,
  install: true,
  include_directories: incdir,
)

copyexif_sources = [
  'copyexif.vala',
  'reporter.vala',
  'utils.vala',
  version_file,
]

executable('copy-exif', copyexif_sources,
  dependencies: basic_deps,
  install: true,
  include_directories: incdir,
)

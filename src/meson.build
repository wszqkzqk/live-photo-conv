version_file = vcs_tag(
   command: ['git', 'describe', '--tags'],
     input: 'version.vala.in',
    output: 'version.vala',
)

executable_sources = [
  'convcli.vala',
  'motionmaker.vala',
  'motionphoto.vala',
  'motionphotoffmpeg.vala',
  'reporter.vala',
  'utils.vala',
  version_file,
]

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

# Check if all GStreamer dependencies are found
if gst.found() and gst_app.found() and gdk_pixbuf.found()
  add_project_arguments('-D', 'ENABLE_GST', language: 'vala')

  basic_deps += [
    gst,
    gst_app,
    gdk_pixbuf
  ]

  executable_sources += [
    'motionphotogst.vala',
    'sample2img.vala'
  ]
else
  message('GStreamer not found, only using FFmpeg command line calls')
endif

executable('motion-photo-conv', executable_sources,
  dependencies: basic_deps,
  install: true,
  include_directories: incdir,
)


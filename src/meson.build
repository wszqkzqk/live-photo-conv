version_file = vcs_tag(
   command: ['git', 'describe', '--tags'],
     input: 'version.vala.in',
    output: 'version.vala',
)

executable_sources = [
  'convcli.vala',
  'reporter.vala',
  'motionphoto.vala',
  'motionmaker.vala',
  version_file,
]

basic_deps = [
  glib,
  gobject,
  gio,
  gmodule,
  gexiv2,
]

executable('motion-photo-conv', executable_sources,
  dependencies: basic_deps,
  install: true,
  include_directories: incdir,
)


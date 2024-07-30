version_file = vcs_tag(
   command: ['git', 'describe', '--tags'],
     input: 'version.vala.in',
    output: 'version.vala',
)

executable_sources = [
  #'main.vala',
  'reporter.vala',
  'parallelmanager.vala',
  'unit.vala',
  'motionphoto.vala',
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


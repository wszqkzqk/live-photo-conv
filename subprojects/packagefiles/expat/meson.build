project('expat', 'c', version: '2.7.5')

inc = include_directories('lib')

expat = library('expat',
  'lib/xmlparse.c',
  'lib/xmltok.c',
  'lib/xmlrole.c',
  include_directories: inc,
  version: meson.project_version(),
  soversion: '1',
  install: true,
)

install_headers('lib/expat.h', 'lib/expat_external.h', subdir: 'expat')

expat_dep = declare_dependency(
  link_with: expat,
  include_directories: inc,
)

import('pkgconfig').generate(
  name: 'expat',
  description: 'XML parser library',
  version: meson.project_version(),
  libraries: expat,
)

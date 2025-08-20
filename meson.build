project('live-photo-conv', ['c', 'vala'],
          version: '0.4.0',
    meson_version: '>= 1.1',
)

# Library versioning
lib_api_version = '0.4'  # GIR version / API version
lib_soversion = '0'      # SONAME version / ABI version

glib = dependency('glib-2.0')
gobject = dependency('gobject-2.0')
gio = dependency('gio-2.0')
gmodule = dependency('gmodule-2.0')
gexiv2 = dependency('gexiv2')

#incdir = include_directories('include')

if target_machine.system() == 'windows'
  add_project_arguments('-D', 'WINDOWS', language: 'vala')
endif

subdir('src')

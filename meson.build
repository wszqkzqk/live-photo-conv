project('live-photo-conv', ['c', 'vala'],
          version: '0.3.8',
    meson_version: '>= 1.1',
)

glib = dependency('glib-2.0')
gobject = dependency('gobject-2.0')
gio = dependency('gio-2.0')
gmodule = dependency('gmodule-2.0')
gexiv2 = dependency('gexiv2')

incdir = include_directories('include')

if target_machine.system() == 'windows'
  add_project_arguments('-D', 'WINDOWS', language: 'vala')
endif

subdir('src')

valadoc = find_program('valadoc', required: get_option('docs'))
if valadoc.found()
  subdir('docs')
endif

project('varallel', ['c', 'vala'],
          version: run_command('git', 'describe', '--tags', check: true).stdout().strip(),
    meson_version: '>= 0.59.0',
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

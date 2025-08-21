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

valadoc = find_program('valadoc', required: get_option('docs'))

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

# Check if all GStreamer dependencies are found
if gst.found() and gst_app.found() and gdk_pixbuf.found()
  add_project_arguments('-D', 'ENABLE_GST', language: 'vala')

  basic_deps += [
    gst,
    gst_app,
    gdk_pixbuf
  ]

  lib_common_sources += [
    'livemakergst.vala',
    'livephotogst.vala',
    'sample2img.vala'
  ]
endif

lib_sources = lib_common_sources + [version_file]

g_ir_compiler = find_program('g-ir-compiler', required: get_option('gir'))
lib_gi_name = 'LivePhotoTools'
lib_gi_version = lib_api_version  # Use centralized API version
lib_gi = 'LivePhotoTools-' + lib_gi_version
lib_gir = lib_gi + '.gir'
lib_typelib = lib_gi + '.typelib'

# If Valadoc is found, generate gir with doc and disable gir generation here
if g_ir_compiler.found() and not valadoc.found()
  liblivephototools = shared_library(
    'livephototools', lib_sources,
    vala_gir: lib_gir,
    vala_args: ['--vapi-comments'],
    dependencies: basic_deps,
    version: meson.project_version(),
    soversion: lib_soversion,
    #include_directories: incdir,
    install: true,
    install_dir: [true, 'include/livephototools', true, true]
  )
else
  liblivephototools = shared_library(
    'livephototools', lib_sources,
    vala_args: ['--vapi-comments'],
    dependencies: basic_deps,
    version: meson.project_version(),
    soversion: lib_soversion,
    #include_directories: incdir,
    install: true,
    install_dir: [true, 'include/livephototools', true]
  )
endif

pkg = import('pkgconfig')
pkg.generate(
  name: 'LivePhotoTools',
  filebase: 'livephototools',
  description: 'A library for live photo conversion',
  libraries: liblivephototools,
  version: meson.project_version(),
  subdirs: 'livephototools',
  requires: basic_deps,
)

executable_names = ['live-photo-conv', 'live-photo-make', 'live-photo-extract', 'live-photo-repair']
executable_bins = []
foreach exe_name : executable_names
  exe_bin = executable(exe_name,
    ['main.vala'],
    install: true,
    link_with: liblivephototools,
    dependencies: basic_deps,
    #include_directories: incdir,
  )
  executable_bins += [exe_bin]
endforeach

copy_img_meta_name = 'copy-img-meta'
copy_img_meta_bin = executable(copy_img_meta_name,
  ['copyimgmeta.vala'],
  install: true,
  link_with: liblivephototools,
  dependencies: basic_deps,
  #include_directories: incdir,
)
executable_names += [copy_img_meta_name]
executable_bins += [copy_img_meta_bin]

help2man_prog = find_program('help2man', required: get_option('manpages'))

if help2man_prog.found()
  foreach exe_bin : executable_bins
    custom_target('manpage-' + exe_bin.name(),
      output : exe_bin.name() + '.1',
      command : [
        help2man_prog,
        '-N',
        '-o',
        '@OUTPUT@',
        exe_bin,
        '--no-discard-stderr',
      ],
    install : true,
    install_dir : get_option('mandir') / 'man1',
    )
  endforeach
endif

# Meson doesn't have buit-in support to use valadoc to generate gir
if valadoc.found()
  deps_command = []

  lib_in_src = []
  foreach src : lib_common_sources
      lib_in_src += [join_paths(meson.global_source_root(), 'src', src)]
  endforeach

  foreach dep : basic_deps
      deps_command += ['--pkg', dep.name()]
  endforeach

  gir_with_doc = custom_target(
    'livephototools gir with doc',
    command: [
        valadoc,
        '--force',
        '--verbose',
        '--package-name', 'liblivephototools',
        '--package-version', meson.project_version(),
        deps_command,
        '--vapidir', join_paths(meson.project_build_root(), 'src'),
        '--vapidir', join_paths(meson.global_source_root(), 'vapi'),
        '--doclet=devhelp',
        '-o', 'docs',
        version_file.full_path(),
        '--gir', '@OUTPUT@',
        '@INPUT@'
    ],
    build_by_default: true,
    input: lib_in_src,
    output: lib_gir,
    depends: liblivephototools,
    install: true,
    install_dir: get_option('datadir') / 'gir-1.0',
  )
endif

if g_ir_compiler.found()
  custom_target(lib_typelib,
    input: liblivephototools,
    output: lib_typelib,
    depends: valadoc.found() ? gir_with_doc : liblivephototools,
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

# Install dependencies files for VAPI
if gst.found() and gst_app.found() and gdk_pixbuf.found()
  install_data('livephototools.deps',
    install_dir: get_option('datadir') / 'vala' / 'vapi'
  )
else
  install_data('livephototools-no-gst.deps',
    rename: 'livephototools.deps',
    install_dir: get_option('datadir') / 'vala' / 'vapi'
  )
endif

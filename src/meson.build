version_file = vcs_tag(
   command: meson.project_version(),
     input: 'version.vala.in',
    output: 'version.vala',
)

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
if with_gst
  lib_common_sources += [
    'livemakergst.vala',
    'livephotogst.vala',
    'sample2img.vala'
  ]
endif

lib_sources = lib_common_sources + [version_file]

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
    dependencies: lib_deps,
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
    dependencies: lib_deps,
    version: meson.project_version(),
    soversion: lib_soversion,
    #include_directories: incdir,
    install: true,
    install_dir: [true, 'include/livephototools', true]
  )
endif

pkg.generate(
  name: 'LivePhotoTools',
  filebase: 'livephototools',
  description: 'A library for live photo conversion',
  libraries: liblivephototools,
  version: meson.project_version(),
  subdirs: 'livephototools',
  requires: lib_deps,
)

# Build only the main executable once
main_exe_name = 'live-photo-conv'
main_exe_bin = executable(main_exe_name,
  ['main.vala'],
  install: true,
  link_with: liblivephototools,
  dependencies: lib_deps,
  #include_directories: incdir,
)

# Sub executable names that should be links/copies of the main binary
sub_exe_names = ['live-photo-make', 'live-photo-extract', 'live-photo-repair']

# Build copy-img-meta separately as it has different sources
copy_img_meta_name = 'copy-img-meta'
copy_img_meta_bin = executable(copy_img_meta_name,
  ['copyimgmeta.vala'],
  install: true,
  link_with: liblivephototools,
  dependencies: lib_deps,
  #include_directories: incdir,
)

# Create symlinks/copies in build directory and install them
symlink_script = meson.project_source_root() / 'scripts' / 'create-binary-symlinks.py'
sub_exe_bins = []
foreach exe_name : sub_exe_names
  # Create link/copy in build directory and install it
  linked_exe = custom_target('link-' + exe_name,
    output: exe_name + (is_windows ? '.exe' : ''),
    command: [
      python,
      symlink_script,
      main_exe_bin.full_path(),
      '@OUTPUT@',
    ],
    depends: main_exe_bin,
    build_by_default: true,
    install: true,
    install_dir: get_option('bindir'),
  )

  sub_exe_bins += [linked_exe]
endforeach

if help2man_prog.found()
  # Generate manpage for main executable
  custom_target('manpage-' + main_exe_name,
    output : main_exe_name + '.1',
    command : [
      help2man_prog,
      '-N',
      '-o',
      '@OUTPUT@',
      main_exe_bin,
      '--no-discard-stderr',
    ],
    install : true,
    install_dir : get_option('mandir') / 'man1',
  )

  # Generate manpages for linked executables
  foreach index : range(sub_exe_names.length())
    custom_target('manpage-' + sub_exe_names[index],
      output : sub_exe_names[index] + '.1',
      command : [
        help2man_prog,
        '-N',
        '-o',
        '@OUTPUT@',
        sub_exe_bins[index].full_path(),
        '--no-discard-stderr',
      ],
      install : true,
      install_dir : get_option('mandir') / 'man1',
      depends : sub_exe_bins[index],
    )
  endforeach
  
  # Generate manpage for copy-img-meta
  custom_target('manpage-' + copy_img_meta_name,
    output : copy_img_meta_name + '.1',
    command : [
      help2man_prog,
      '-N',
      '-o',
      '@OUTPUT@',
      copy_img_meta_bin,
      '--no-discard-stderr',
    ],
    install : true,
    install_dir : get_option('mandir') / 'man1',
  )
endif

# Meson doesn't have buit-in support to use valadoc to generate gir
if valadoc.found()
  deps_command = []

  lib_in_src = []
  foreach src : lib_common_sources
      lib_in_src += [join_paths(meson.global_source_root(), 'src', src)]
  endforeach

  foreach dep : lib_deps
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
if with_gst
  install_data('livephototools.deps',
    install_dir: get_option('datadir') / 'vala' / 'vapi'
  )
else
  install_data('livephototools-no-gst.deps',
    rename: 'livephototools.deps',
    install_dir: get_option('datadir') / 'vala' / 'vapi'
  )
endif

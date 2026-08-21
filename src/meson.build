localedir = join_paths(get_option('prefix'), get_option('localedir'))
constants_data = configuration_data()
constants_data.set_quoted('VERSION', vcs_version)
constants_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
constants_data.set_quoted('LOCALEDIR', localedir)
constants_file = configure_file(
    input: 'constants.vala.in',
    output: 'constants.vala',
    configuration: constants_data,
)

lib_common_sources = [
  'backend.vala',
  'errordomains.vala',
  'livemaker.vala',
  'livemakerffmpeg.vala',
  'livephoto.vala',
  'livephotoffmpeg.vala',
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

lib_sources = lib_common_sources + [constants_file]

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
    vala_args: ['--vapi-comments'] + android_vala_args,
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
    vala_args: ['--vapi-comments'] + android_vala_args,
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
  url: 'https://github.com/wszqkzqk/live-photo-conv',
  libraries: liblivephototools,
  version: meson.project_version(),
  subdirs: 'livephototools',
  requires: lib_deps,
)

# CLI tools are meaningless on Android
if not is_android
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
endif

# Build GTK4/LibAdwaita GUI
gui_name = 'live-photo-conv-gtk'
gui_sources = ['gui.vala']
if with_gui
  gui_deps = lib_deps + [gtk4_dep, libadwaita_dep]

  # Embed application icons via GResource on non-Linux
  if not is_freedesktop
    gui_sources += gnome.compile_resources('live-photo-conv-gtk-resources',
      'icons.gresource.xml',
      source_dir: '..',
    )
  endif

  # No system icon theme on Android; bundle the symbolic icons we use
  if is_android
    gui_sources += gnome.compile_resources('live-photo-conv-gtk-android-icons',
      '../android/icons.gresource.xml',
      c_name: 'icons_android',
      source_dir: '../android',
    )
  endif

  if is_windows
    # Embed application icon as a Windows resource
    win_rc = configure_file(
      input: files('../assets/live-photo-conv-gtk.rc'),
      output: 'live-photo-conv-gtk.rc',
      copy: true,
    )
    configure_file(
      input: files('../assets/icon.ico'),
      output: 'icon.ico',
      copy: true,
    )
    gui_sources += import('windows').compile_resources(win_rc)
  endif

  if is_android
    # Loaded as a shared library by the GTK Android runtime, which calls
    # the exported main().
    executable(gui_name,
      gui_sources,
      android_exe_type: 'application',
      install: true,
      link_with: liblivephototools,
      dependencies: gui_deps,
      vala_args: android_gui_vala_args,
    )
  else
    executable(gui_name,
      gui_sources,
      install: true,
      link_with: liblivephototools,
      dependencies: gui_deps,
      win_subsystem: 'windows',
    )
  endif

  if is_freedesktop
    # Install desktop file and hicolor icon (freedesktop / Linux)
    install_data('../assets/com.github.wszqkzqk.live-photo-conv.desktop',
      install_dir: get_option('datadir') / 'applications',
    )
    install_data('../assets/icon.svg',
      install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps',
      rename: 'com.github.wszqkzqk.live-photo-conv.svg',
    )
  endif
endif

# Create symlinks/copies in build directory and install them
if not is_android
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
      install: is_windows, # Workaround for https://github.com/mesonbuild/meson/issues/12710
      install_dir: get_option('bindir'),
    )
    # Workaround for https://github.com/mesonbuild/meson/issues/12710
    if not is_windows
      install_symlink(
        exe_name,
        pointing_to: main_exe_name,
        install_dir: get_option('bindir')
      )
    endif

    sub_exe_bins += [linked_exe]
  endforeach

  if help2man_prog.found() and meson.can_run_host_binaries()
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
        constants_file.full_path(),
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

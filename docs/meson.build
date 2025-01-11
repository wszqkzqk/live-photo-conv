valadoc = find_program('valadoc')

deps_command = []

foreach dep : basic_deps
    deps_command += ['--pkg', dep.name()]
endforeach

doc_command = [
    valadoc,
    '--force',
    '--verbose',
    '--package-name', 'liblivephototools',
    '--package-version', meson.project_version(),
    deps_command,
    '--vapidir', join_paths(meson.project_build_root(), 'src'),
    '--vapidir', join_paths(meson.global_source_root(), 'vapi'),
    '--doclet=html',
    '--use-svg-images'
]

doc_dir = 'livephototools'

lib_in_src = []
foreach src : lib_common_sources
    lib_in_src += [join_paths(meson.global_source_root(), 'src', src)]
endforeach

custom_target(
    'livephototools documentation',
    command: [
        doc_command,
        '-o', '@OUTPUT@',
        # Addition version_file
        version_file.full_path(),
        '@INPUT@'
    ],
    build_by_default: true,
    input: lib_in_src,
    output: doc_dir,
    depends: liblivephototools
)

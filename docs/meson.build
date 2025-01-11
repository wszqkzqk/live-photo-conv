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

lib_in_src = []
foreach src : lib_sources
    lib_in_src += [join_paths(meson.global_source_root(), 'src', src)]
endforeach

doc_target = custom_target(
    'library documentation',
    command: [
        doc_command,
        '-o', '@OUTPUT@',
        '@INPUT@'
    ],
    build_by_default: true,
    input: lib_in_src,
    output: 'library'
)

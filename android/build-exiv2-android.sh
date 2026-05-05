#!/bin/bash
# Cross-compile Expat, Exiv2, and GExiv2 for Android
# Usage: ./build-exiv2-android.sh <ndk_path> <api_level> <abi> <prefix>
#
# Example: ./build-exiv2-android.sh /opt/android/ndk/27.2.12479018 35 arm64-v8a /opt/android-deps

set -euo pipefail

NDK="${1:?Usage: $0 <ndk_path> <api_level> <abi> <prefix>}"
API="${2:?}"
ABI="${3:?}"
PREFIX="${4:?}"

TOOLCHAIN="${NDK}/build/cmake/android.toolchain.cmake"
export PATH="${NDK}/toolchains/llvm/prebuilt/linux-x86_64/bin:${PATH}"

# Version pins
EXPAT_VERSION="2.7.5"
EXIV2_VERSION="0.28.8"
GEXIV2_VERSION="0.16.0"

WORK="/tmp/build-android-deps"
mkdir -p "${WORK}" "${PREFIX}"

echo "=== Building Expat ${EXPAT_VERSION} (Android) ==="
echo "  Downloading..."
wget -nv "https://github.com/libexpat/libexpat/releases/download/R_$(echo ${EXPAT_VERSION} | tr . _)/expat-${EXPAT_VERSION}.tar.xz" -O "${WORK}/expat.tar.xz"
echo "  Extracting..."
    tar -xf "${WORK}/expat.tar.xz" -C "${WORK}/"

    cmake -S "${WORK}/expat-${EXPAT_VERSION}" -B "${WORK}/build-expat" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN}" \
        -DANDROID_ABI="${ABI}" \
        -DANDROID_PLATFORM="android-${API}" \
        -DANDROID_STL="c++_shared" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DEXPAT_BUILD_TOOLS=OFF \
        -DEXPAT_BUILD_EXAMPLES=OFF \
        -DEXPAT_BUILD_TESTS=OFF \
        -DEXPAT_BUILD_DOCS=OFF \
        -DEXPAT_SHARED_LIBS=ON
    cmake --build "${WORK}/build-expat" --parallel "$(nproc)"
    cmake --install "${WORK}/build-expat"
    rm -rf "${WORK}/expat-${EXPAT_VERSION}" "${WORK}/build-expat" "${WORK}/expat.tar.xz"
    echo "Expat ${EXPAT_VERSION} installed (Android)."

echo "=== Building Exiv2 ${EXIV2_VERSION} (Android) ==="
echo "  Downloading..."
wget -nv "https://github.com/Exiv2/exiv2/archive/refs/tags/v${EXIV2_VERSION}.tar.gz" -O "${WORK}/exiv2.tar.gz"
echo "  Extracting..."
tar -xf "${WORK}/exiv2.tar.gz" -C "${WORK}/"

    cmake -S "${WORK}/exiv2-${EXIV2_VERSION}" -B "${WORK}/build-exiv2" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN}" \
        -DANDROID_ABI="${ABI}" \
        -DANDROID_PLATFORM="android-${API}" \
        -DANDROID_STL="c++_shared" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_PREFIX_PATH="${PREFIX}" \
        -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=BOTH \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH \
        -DCMAKE_CXX_FLAGS="-Dlibiconv_open=iconv_open -Dlibiconv=iconv -Dlibiconv_close=iconv_close" \
        -DBUILD_SHARED_LIBS=ON \
        -DEXIV2_ENABLE_XMP=ON \
        -DEXIV2_ENABLE_PNG=ON \
        -DEXIV2_ENABLE_NLS=OFF \
        -DEXIV2_ENABLE_BROTLI=OFF \
        -DEXIV2_ENABLE_INIH=OFF \
        -DEXIV2_ENABLE_WEBREADY=OFF \
        -DEXIV2_ENABLE_CURL=OFF \
        -DEXIV2_ENABLE_VIDEO=OFF \
        -DEXIV2_ENABLE_BMFF=ON \
        -DEXIV2_BUILD_SAMPLES=OFF \
        -DEXIV2_BUILD_EXIV2_COMMAND=OFF \
        -DEXIV2_BUILD_UNIT_TESTS=OFF \
        -DEXIV2_BUILD_DOC=OFF \
        -DEXIV2_TEAM_EXTRA_WARNINGS=OFF
    cmake --build "${WORK}/build-exiv2" --parallel "$(nproc)"
    cmake --install "${WORK}/build-exiv2"
    rm -rf "${WORK}/exiv2-${EXIV2_VERSION}" "${WORK}/build-exiv2" "${WORK}/exiv2.tar.gz"
    echo "Exiv2 ${EXIV2_VERSION} installed (Android)."

# ── Native builds (for VAPI generation) ──
# GExiv2's VAPI requires a native build with introspection=enabled,
# which needs native Expat + Exiv2 libraries of the same version.
# Native x86_64 builds are fast (no NDK toolchain overhead).
NATIVE_PREFIX="${WORK}/native-deps"
mkdir -p "${NATIVE_PREFIX}"

echo "=== Building Expat ${EXPAT_VERSION} (native) ==="
echo "  Downloading..."
wget -nv "https://github.com/libexpat/libexpat/releases/download/R_$(echo ${EXPAT_VERSION} | tr . _)/expat-${EXPAT_VERSION}.tar.xz" -O "${WORK}/expat-native.tar.xz"
tar -xf "${WORK}/expat-native.tar.xz" -C "${WORK}/"
    cmake -S "${WORK}/expat-${EXPAT_VERSION}" -B "${WORK}/build-expat-native" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
        -DEXPAT_BUILD_TOOLS=OFF \
        -DEXPAT_BUILD_EXAMPLES=OFF \
        -DEXPAT_BUILD_TESTS=OFF \
        -DEXPAT_BUILD_DOCS=OFF \
        -DEXPAT_SHARED_LIBS=ON
    cmake --build "${WORK}/build-expat-native" --parallel "$(nproc)"
    cmake --install "${WORK}/build-expat-native"
    rm -rf "${WORK}/expat-${EXPAT_VERSION}" "${WORK}/build-expat-native" "${WORK}/expat-native.tar.xz"
    echo "Expat ${EXPAT_VERSION} installed (native)."

echo "=== Building Exiv2 ${EXIV2_VERSION} (native) ==="
echo "  Downloading..."
wget -nv "https://github.com/Exiv2/exiv2/archive/refs/tags/v${EXIV2_VERSION}.tar.gz" -O "${WORK}/exiv2-native.tar.gz"
echo "  Extracting..."
tar -xf "${WORK}/exiv2-native.tar.gz" -C "${WORK}/"
    cmake -S "${WORK}/exiv2-${EXIV2_VERSION}" -B "${WORK}/build-exiv2-native" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${NATIVE_PREFIX}" \
        -DCMAKE_PREFIX_PATH="${NATIVE_PREFIX}" \
        -DBUILD_SHARED_LIBS=ON \
        -DEXIV2_ENABLE_XMP=ON \
        -DEXIV2_ENABLE_PNG=ON \
        -DEXIV2_ENABLE_NLS=OFF \
        -DEXIV2_ENABLE_BROTLI=OFF \
        -DEXIV2_ENABLE_INIH=OFF \
        -DEXIV2_ENABLE_WEBREADY=OFF \
        -DEXIV2_ENABLE_CURL=OFF \
        -DEXIV2_ENABLE_VIDEO=OFF \
        -DEXIV2_ENABLE_BMFF=ON \
        -DEXIV2_BUILD_SAMPLES=OFF \
        -DEXIV2_BUILD_EXIV2_COMMAND=OFF \
        -DEXIV2_BUILD_UNIT_TESTS=OFF \
        -DEXIV2_BUILD_DOC=OFF \
        -DEXIV2_TEAM_EXTRA_WARNINGS=OFF
    cmake --build "${WORK}/build-exiv2-native" --parallel "$(nproc)"
    cmake --install "${WORK}/build-exiv2-native"
    rm -rf "${WORK}/exiv2-${EXIV2_VERSION}" "${WORK}/build-exiv2-native" "${WORK}/exiv2-native.tar.gz"
    echo "Exiv2 ${EXIV2_VERSION} installed (native)."

echo "=== Building GExiv2 ${GEXIV2_VERSION} ==="
if [ ! -f "${PREFIX}/lib/pkgconfig/gexiv2.pc" ]; then
    echo "  Downloading..."
    wget -nv "https://download.gnome.org/sources/gexiv2/${GEXIV2_VERSION%.*}/gexiv2-${GEXIV2_VERSION}.tar.xz" -O "${WORK}/gexiv2.tar.xz"
    echo "  Extracting..."
    tar -xf "${WORK}/gexiv2.tar.xz" -C "${WORK}/"

    SRC="${WORK}/gexiv2-${GEXIV2_VERSION}"

    # Step 1: Native build (x86_64) to generate the VAPI file.
    # Uses the same Exiv2/Expat version via the native prefix for VAPI accuracy.
    echo "  Building natively for VAPI..."
    PKG_CONFIG_PATH="${NATIVE_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
    meson setup "${WORK}/build-gexiv2-native" "${SRC}" \
        --prefix "${WORK}/native-install" \
        -Dintrospection=true \
        -Dvapi=true \
        -Dgtk_doc=false \
        -Dtests=false \
        -Dtools=false
    meson compile -C "${WORK}/build-gexiv2-native"
    meson install -C "${WORK}/build-gexiv2-native"

    # Copy the generated VAPI for valac to find during cross-compilation
    mkdir -p "${PREFIX}/share/vala/vapi"
    cp "${WORK}/native-install/share/vala/vapi/"*.vapi "${PREFIX}/share/vala/vapi/" 2>/dev/null || true
    cp "${WORK}/native-install/share/vala/vapi/"*.deps "${PREFIX}/share/vala/vapi/" 2>/dev/null || true

    # Step 2: Cross-compile for Android (no introspection/VAPI needed)
    echo "  Cross-compiling for Android..."
    cat > "${WORK}/cross-gexiv2.txt" << CROSSEOF
[constants]
ndk = '${NDK}'

[binaries]
c = ndk / 'toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android${API}-clang'
cpp = ndk / 'toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android${API}-clang++'
ar = ndk / 'toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar'
strip = ndk / 'toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip'
pkgconfig = 'pkg-config'
cmake = 'cmake'

[built-in options]
c_args = ['-DANDROID', '-D__ANDROID_API__=${API}']
cpp_args = ['-DANDROID', '-D__ANDROID_API__=${API}']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'

[properties]
pkg_config_libdir = '${PREFIX}/lib/pkgconfig'
sys_root = '${PREFIX}'
CROSSEOF

    # Native file: override build-machine tools so meson finds x86_64 binaries
    # for code generation (glib-mkenums, etc.) instead of aarch64 ones from $PREFIX.
    cat > "${WORK}/native-file.txt" << NATIVEEOF
[binaries]
glib-mkenums = '/usr/bin/glib-mkenums'
NATIVEEOF

    export PKG_CONFIG_LIBDIR_FOR_BUILD=""
    unset PKG_CONFIG_LIBDIR
    unset PKG_CONFIG_SYSROOT_DIR

    meson setup "${WORK}/build-gexiv2" "${SRC}" \
        --cross-file "${WORK}/cross-gexiv2.txt" \
        --native-file "${WORK}/native-file.txt" \
        --cross-file "${WORK}/cross-gexiv2.txt" \
        --prefix "${PREFIX}" \
        -Dintrospection=false \
        -Dvapi=false \
        -Dpython3=false \
        -Dgtk_doc=false \
        -Dtests=false \
        -Dtools=false
    meson compile -C "${WORK}/build-gexiv2"
    meson install -C "${WORK}/build-gexiv2"
    rm -rf "${SRC}" "${WORK}/build-gexiv2" "${WORK}/build-gexiv2-native" "${WORK}/native-install" "${WORK}/gexiv2.tar.xz"
    echo "GExiv2 ${GEXIV2_VERSION} installed."
else
    echo "GExiv2 already installed, skipping."
fi

rm -rf "${WORK}"
echo "=== All dependencies built ==="
ls -la "${PREFIX}/lib/pkgconfig/"

#!/bin/bash
# Generate GExiv2 VAPI files natively for Android builds.
# Expat, Exiv2, and GExiv2 Android .so files are built as meson subprojects
# (see subprojects/expat.wrap, exiv2.wrap, gexiv2.wrap).
# Usage: ./build-exiv2-android.sh <ndk_path> <api_level> <abi> <prefix>
#
# Example: ./build-exiv2-android.sh /opt/android/ndk/27.2.12479018 35 arm64-v8a /opt/android-deps

set -euo pipefail

NDK="${1:?Usage: $0 <ndk_path> <api_level> <abi> <prefix>}"
API="${2:?}"
ABI="${3:?}"
PREFIX="${4:?}"

# Version pins
EXPAT_VERSION="2.7.5"
EXIV2_VERSION="0.28.8"
GEXIV2_VERSION="0.16.0"

WORK="/tmp/build-android-deps"
mkdir -p "${WORK}" "${PREFIX}"

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

echo "=== Building GExiv2 ${GEXIV2_VERSION} VAPI (native only) ==="
# GExiv2's Android cross-compilation is handled as a meson subproject
# (see subprojects/gexiv2.wrap) during the main project build.
# Here we only build natively to generate the VAPI files that valac needs.
if [ ! -f "${PREFIX}/share/vala/vapi/gexiv2-0.16.vapi" ]; then
    echo "  Downloading..."
    wget -nv "https://download.gnome.org/sources/gexiv2/${GEXIV2_VERSION%.*}/gexiv2-${GEXIV2_VERSION}.tar.xz" -O "${WORK}/gexiv2.tar.xz"
    echo "  Extracting..."
    tar -xf "${WORK}/gexiv2.tar.xz" -C "${WORK}/"

    SRC="${WORK}/gexiv2-${GEXIV2_VERSION}"

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

    # Copy the generated VAPI for valac to find during Android compilation
    mkdir -p "${PREFIX}/share/vala/vapi"
    cp "${WORK}/native-install/share/vala/vapi/"*.vapi "${PREFIX}/share/vala/vapi/" 2>/dev/null || true
    cp "${WORK}/native-install/share/vala/vapi/"*.deps "${PREFIX}/share/vala/vapi/" 2>/dev/null || true

    rm -rf "${SRC}" "${WORK}/build-gexiv2-native" "${WORK}/native-install" "${WORK}/gexiv2.tar.xz"
    echo "GExiv2 VAPI generated."
else
    echo "GExiv2 VAPI already present, skipping."
fi

rm -rf "${WORK}"
echo "=== All dependencies built ==="

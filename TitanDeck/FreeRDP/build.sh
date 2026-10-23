#!/usr/bin/env bash
# Builds FreeRDP + OpenSSL as static libraries for iOS and packages them as
# FreeRDPKit.xcframework (iPad, arm64 simulator, x86_64 simulator for Intel Macs)
# plus a flat Headers folder. Needs macOS with Xcode and cmake.
#
# You normally don't run this: CI builds it once per version and publishes it as
# a GitHub release asset, and fetch.sh downloads it. Takes 30-60 minutes.
#
# Usage: ./build.sh [output-dir]   (default: ../Vendor)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=versions.env
source "$HERE/versions.env"

OUT="${1:-$HERE/../Vendor}"
WORK="${WORK:-$HERE/.build}"
JOBS="$(sysctl -n hw.ncpu)"
mkdir -p "$WORK" "$OUT"
OUT="$(cd "$OUT" && pwd)"

log() { printf '\n==> %s\n' "$*"; }

# run_logged <logfile> <command...>: quiet on success, shows the log tail on failure.
run_logged() {
    local logfile="$1"; shift
    if ! "$@" >"$logfile" 2>&1; then
        echo "FAILED: $*" >&2
        tail -n 150 "$logfile" >&2
        exit 1
    fi
}

# --- Sources ---------------------------------------------------------------

fetch_sources() {
    if [ ! -d "$WORK/openssl-src" ]; then
        log "Downloading $OPENSSL_VERSION"
        curl -fsSL -o "$WORK/openssl.tar.gz" \
            "https://github.com/openssl/openssl/releases/download/$OPENSSL_VERSION/$OPENSSL_VERSION.tar.gz"
        echo "$OPENSSL_SHA256  $WORK/openssl.tar.gz" | shasum -a 256 -c -
        mkdir -p "$WORK/openssl-src"
        tar xzf "$WORK/openssl.tar.gz" -C "$WORK/openssl-src" --strip-components 1
    fi
    if [ ! -d "$WORK/freerdp-src" ]; then
        log "Cloning FreeRDP $FREERDP_VERSION"
        git clone --quiet --depth 1 --branch "$FREERDP_VERSION" \
            https://github.com/FreeRDP/FreeRDP.git "$WORK/freerdp-src"
    fi
}

# --- OpenSSL ---------------------------------------------------------------

# build_openssl <slice> <openssl-target> <min-version-flag>
build_openssl() {
    local slice="$1" target="$2" minflag="$3"
    local build="$WORK/$slice/openssl-build" prefix="$WORK/$slice/openssl"
    [ -f "$prefix/lib/libssl.a" ] && return
    log "OpenSSL for $slice ($target)"
    rm -rf "$build" && mkdir -p "$build"
    (
        cd "$build"
        run_logged "$build/configure.log" "$WORK/openssl-src/Configure" "$target" \
            "$minflag=$DEPLOYMENT_TARGET" no-shared no-tests no-apps no-docs \
            --prefix="$prefix" --libdir=lib
        run_logged "$build/make.log" make -j"$JOBS" build_libs
        run_logged "$build/install.log" make install_dev
    )
}

# --- FreeRDP ---------------------------------------------------------------

# build_freerdp <slice> <toolchain-platform>
build_freerdp() {
    local slice="$1" platform="$2"
    local build="$WORK/$slice/freerdp-build" prefix="$WORK/$slice/freerdp" ssl="$WORK/$slice/openssl"
    [ -f "$prefix/lib/libfreerdp3.a" ] && return
    log "FreeRDP for $slice ($platform)"
    rm -rf "$build" && mkdir -p "$build"
    run_logged "$build/../freerdp-configure.log" cmake -S "$WORK/freerdp-src" -B "$build" -G "Unix Makefiles" \
        -DCMAKE_TOOLCHAIN_FILE="$WORK/freerdp-src/cmake/ios.toolchain.cmake" \
        -DPLATFORM="$platform" \
        -DDEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
        -DENABLE_BITCODE=OFF \
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$prefix" \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_FIND_ROOT_PATH="$ssl" \
        -DOPENSSL_ROOT_DIR="$ssl" \
        -DOPENSSL_USE_STATIC_LIBS=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DWITH_CLIENT=OFF -DWITH_CLIENT_COMMON=ON -DWITH_CLIENT_CHANNELS=ON \
        -DWITH_SERVER=OFF -DWITH_SAMPLE=OFF -DWITH_SHADOW=OFF -DWITH_PROXY=OFF \
        -DWITH_PLATFORM_SERVER=OFF -DWITH_WINPR_TOOLS=OFF -DWITH_MANPAGES=OFF \
        -DWITH_FFMPEG=OFF -DWITH_SWSCALE=OFF -DWITH_OPENH264=OFF -DWITH_VIDEOTOOLBOX=OFF \
        -DWITH_JSON_DISABLED=ON -DWITH_OPUS=OFF -DWITH_URIPARSER=OFF -DWITH_KRB5=OFF \
        -DWITH_PCSC=OFF -DWITH_SMARTCARD_EMULATE=OFF -DWITH_FUSE=OFF -DWITH_CUPS=OFF \
        -DWITH_PULSE=OFF -DWITH_ALSA=OFF -DWITH_OSS=OFF \
        -DWINPR_UTILS_IMAGE_PNG=OFF -DWINPR_UTILS_IMAGE_WEBP=OFF -DWINPR_UTILS_IMAGE_JPEG=OFF \
        -DWITH_JPEG=OFF \
        -DWITH_INTERNAL_RC4=ON -DWITH_INTERNAL_MD4=ON -DWITH_INTERNAL_MD5=ON \
        -DWITHOUT_FREERDP_3x_DEPRECATED=ON -DWITHOUT_WINPR_3x_DEPRECATED=ON \
        -DCHANNEL_URBDRC=OFF -DCHANNEL_REMDESK=OFF -DCHANNEL_RDPSND=OFF -DCHANNEL_AUDIN=OFF \
        -DCHANNEL_RDPDR=OFF -DCHANNEL_PRINTER=OFF -DCHANNEL_SMARTCARD=OFF -DCHANNEL_DRIVE=OFF \
        -DCHANNEL_SERIAL=OFF -DCHANNEL_PARALLEL=OFF -DCHANNEL_RDPECAM=OFF -DCHANNEL_TSMF=OFF \
        -DCHANNEL_VIDEO=OFF -DCHANNEL_GEOMETRY=OFF -DCHANNEL_LOCATION=OFF -DCHANNEL_RAIL=OFF \
        -DCHANNEL_ENCOMSP=OFF -DCHANNEL_SSHAGENT=OFF -DCHANNEL_RDP2TCP=OFF -DCHANNEL_RDPEMSC=OFF
    run_logged "$build/../freerdp-build.log" cmake --build "$build" --parallel "$JOBS"
    run_logged "$build/../freerdp-install.log" cmake --install "$build"
}

# --- Packaging -------------------------------------------------------------

# merge_slice <slice> -> $WORK/<slice>/libFreeRDPKit.a
merge_slice() {
    local slice="$1"
    local libs
    libs=$(find "$WORK/$slice/freerdp/lib" "$WORK/$slice/openssl/lib" -name '*.a' | sort)
    log "Merging $slice: $(echo "$libs" | xargs -n1 basename | tr '\n' ' ')"
    # shellcheck disable=SC2086
    libtool -static -no_warning_for_no_symbols -o "$WORK/$slice/libFreeRDPKit.a" $libs
}

build_slice() {
    local slice="$1" ossl_target="$2" minflag="$3" platform="$4"
    build_openssl "$slice" "$ossl_target" "$minflag"
    build_freerdp "$slice" "$platform"
    merge_slice "$slice"
}

fetch_sources
build_slice ios-arm64 ios64-xcrun -mios-version-min OS64
build_slice sim-arm64 iossimulator-arm64-xcrun -mios-simulator-version-min SIMULATORARM64
build_slice sim-x86_64 iossimulator-x86_64-xcrun -mios-simulator-version-min SIMULATOR64

log "Combining simulator slices"
mkdir -p "$WORK/sim"
lipo -create "$WORK/sim-arm64/libFreeRDPKit.a" "$WORK/sim-x86_64/libFreeRDPKit.a" \
    -output "$WORK/sim/libFreeRDPKit.a"

log "Creating FreeRDPKit.xcframework"
rm -rf "$OUT/FreeRDPKit.xcframework" "$OUT/FreeRDPHeaders"
xcodebuild -create-xcframework \
    -library "$WORK/ios-arm64/libFreeRDPKit.a" \
    -library "$WORK/sim/libFreeRDPKit.a" \
    -output "$OUT/FreeRDPKit.xcframework"

# One flat header tree (freerdp/..., winpr/...) for HEADER_SEARCH_PATHS.
mkdir -p "$OUT/FreeRDPHeaders"
cp -R "$WORK/ios-arm64/freerdp/include/freerdp3/." "$OUT/FreeRDPHeaders/"
cp -R "$WORK/ios-arm64/freerdp/include/winpr3/." "$OUT/FreeRDPHeaders/"

cp "$HERE/versions.env" "$OUT/FreeRDPKit.versions.env"
log "Done: $OUT/FreeRDPKit.xcframework"

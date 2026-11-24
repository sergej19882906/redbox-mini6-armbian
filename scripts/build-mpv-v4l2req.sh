#!/bin/bash
# Build mpv + FFmpeg (v4l2-request hwaccel) for aarch64 Debian trixie.
# Runs INSIDE an arm64 container (e.g. arm64v8/debian:trixie).
# Produces /ws/mpv-v4l2req.tar.gz: /usr/local/bin/mpv + /usr/local/lib + /usr/local/etc/mpv
# plus non-base runtime libs mpv links against.
set -euo pipefail

OUT="${OUT:-/out}"
WS="${WS:-/ws}"
export DEBIAN_FRONTEND=noninteractive

if [ -f "$WS/mpv-v4l2req.tar.gz" ]; then
    echo "tarball already present (cache hit), skipping build"
    exit 0
fi

apt-get update -qq
apt-get install -y --no-install-recommends \
    build-essential git pkg-config ca-certificates nasm yasm \
    meson ninja-build file \
    libasound2-dev libdrm-dev libass-dev libudev-dev libepoxy-dev \
    libx11-dev libxext-dev libxrandr-dev libxinerama-dev \
    libgl-dev libegl-dev

mkdir -p "$OUT"
rm -rf "$OUT"/*

cd /usr/src
git clone -q --depth 1 -b n9.0.2 https://github.com/FFmpeg/FFmpeg.git ffmpeg
cd ffmpeg
for p in /ws/patches/ffmpeg-v4l2request/*.patch; do
    git apply -C1 -p1 "$p"
done
./configure --prefix=/usr/local \
    --disable-debug --disable-doc --disable-programs --disable-ffplay \
    --disable-static --enable-shared --enable-gpl --enable-version3 \
    --enable-v4l2-request \
    --extra-cflags="-Wno-error=incompatible-pointer-types"
make -j"$(nproc)"
make install
ldconfig

cd /usr/src
git clone -q --depth 1 -b v7.387.0 https://github.com/haasn/libplacebo.git
cd libplacebo
git submodule update --init --depth 1 3rdparty/glad 3rdparty/jinja 3rdparty/markupsafe
meson setup build --prefix=/usr/local \
    -Dvulkan=disabled -Dglslang=disabled -Dshaderc=disabled \
    -Dd3d11=disabled -Dlibdovi=disabled -Dlcms=disabled
ninja -C build
ninja -C build install
ldconfig

cd /usr/src
git clone -q --depth 1 -b v0.42.0 https://github.com/mpv-player/mpv.git
cd mpv
meson setup build --prefix=/usr/local
ninja -C build
ninja -C build install
ldconfig

test -x /usr/local/bin/mpv
mkdir -p "$OUT/usr/local/bin" "$OUT/usr/local/etc/mpv"
cp /usr/local/bin/mpv "$OUT/usr/local/bin/mpv"
printf 'hwdec=v4l2request\nvo=gpu-next\n' > "$OUT/usr/local/etc/mpv/mpv.conf"

# collect all non-glibc libs mpv links against (incl. custom ffmpeg libs)
LIBS=$(ldd /usr/local/bin/mpv | awk '{print $3}' | grep -v '^$' | sort -u)
for lib in $LIBS; do
    case "$lib" in
        /lib/ld-*|*/libc.so*|*/libpthread*|*/libm.so*|*/libdl*|*/librt*) continue ;;
    esac
    rel="${lib#/}"
    mkdir -p "$OUT/$(dirname "$rel")"
    cp -L "$lib" "$OUT/$rel"
done

cd "$OUT"
tar czf "$WS/mpv-v4l2req.tar.gz" \
    usr/local/bin/mpv usr/local/etc/mpv usr/local/lib/libav* \
    usr/local/lib/libswscale* usr/local/lib/libswresample* usr/local/lib/libpostproc* \
    usr/lib/aarch64-linux-gnu/

echo "built: $WS/mpv-v4l2req.tar.gz"

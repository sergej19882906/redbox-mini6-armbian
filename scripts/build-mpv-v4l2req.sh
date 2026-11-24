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
    libasound2-dev libdrm-dev libplacebo-dev libass-dev \
    libx11-dev libxext-dev libxrandr-dev libxinerama-dev \
    libgl-dev libegl-dev

rm -rf "$OUT"

cd /usr/src
git clone -q --depth 1 -b v4l2-request-hwaccel https://github.com/kwiboo/FFmpeg.git ffmpeg
cd ffmpeg
./configure --prefix=/usr/local \
    --disable-debug --disable-doc --disable-programs --disable-ffplay \
    --disable-static --enable-shared --enable-gpl --enable-version3
make -j"$(nproc)"
make DESTDIR="$OUT" install
ldconfig

cd /usr/src
git clone -q --depth 1 -b v0.42.0 https://github.com/mpv-player/mpv.git
cd mpv
meson setup build --prefix=/usr/local
ninja -C build
meson install -C build --destdir "$OUT"

mkdir -p "$OUT/usr/local/etc/mpv"
printf 'hwdec=v4l2request\nvo=gpu-next\n' > "$OUT/usr/local/etc/mpv/mpv.conf"

test -x "$OUT/usr/local/bin/mpv"

# collect all non-glibc libs mpv links against (incl. custom ffmpeg libs)
LIBS=$(ldd "$OUT/usr/local/bin/mpv" | awk '{print $3}' | grep -v '^$' | sort -u)
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

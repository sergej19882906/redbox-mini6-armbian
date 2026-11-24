#!/bin/bash
# Build & install mpv + FFmpeg v4l2-request inside a built Armbian .img (chroot via qemu).
# Gives hardware playback (cedrus V4L2 stateless) for H.264/HEVC/VP8/MPEG2.
# Usage: sudo install-mpv-hwdec.sh /path/to/image.img
set -euo pipefail

IMG="$1"
ROOT=$(mktemp -d)
LOOP=""
CLEANED=0

cleanup() {
    [ "$CLEANED" -eq 1 ] && return 0
    umount "$ROOT/dev/pts" 2>/dev/null || true
    umount "$ROOT/proc" "$ROOT/sys" "$ROOT/dev" 2>/dev/null || true
    umount "$ROOT" 2>/dev/null || true
    if [ -n "$LOOP" ]; then
        losetup -d "$LOOP" 2>/dev/null || true
    fi
    return 0
}
trap cleanup EXIT

mount_root() {
    LOOP=$(losetup -fP --show "$IMG")
    for i in $(seq 1 30); do
        [ -b "${LOOP}p2" ] && break
        partprobe "$LOOP" 2>/dev/null || true
        sleep 1
    done
    [ -b "${LOOP}p2" ] || { echo "partition ${LOOP}p2 not found in $IMG" >&2; return 1; }
    mount "${LOOP}p2" "$ROOT"
    echo "rootfs mounted from ${LOOP}p2"
}

mount_root

if [ ! -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
fi
if [ ! -f /usr/bin/qemu-aarch64-static ]; then
    cid=$(docker create multiarch/qemu-user-static)
    docker cp "$cid:/usr/bin/qemu-aarch64-static" /usr/bin/qemu-aarch64-static
    docker rm "$cid" >/dev/null
fi
cp /usr/bin/qemu-aarch64-static "$ROOT/usr/bin/"
cat /etc/resolv.conf > "$ROOT/etc/resolv.conf"

mount --bind /dev "$ROOT/dev"
mount --bind /dev/pts "$ROOT/dev/pts" 2>/dev/null || true
mount --bind /proc "$ROOT/proc"
mount --bind /sys "$ROOT/sys"

if [ -f /tmp/mpv-v4l2req.tar.gz ]; then
    echo "restoring cached mpv/ffmpeg..."
    tar tzf /tmp/mpv-v4l2req.tar.gz >/dev/null
    tar xzf /tmp/mpv-v4l2req.tar.gz -C "$ROOT/"
    chroot "$ROOT" ldconfig
else
    cat > "$ROOT/root/build-mpv.sh" <<'CHROOT_SCRIPT'
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

apt-get update -qq
apt-get install -y --no-install-recommends \
    build-essential git pkg-config ca-certificates nasm yasm patch \
    meson ninja-build \
    libasound2-dev libdrm-dev libass-dev libudev-dev libepoxy-dev \
    libx11-dev libxext-dev libxrandr-dev libxinerama-dev \
    libgl-dev libegl-dev

cd /usr/src
git clone -q --depth 1 -b n9.0.2 https://github.com/FFmpeg/FFmpeg.git ffmpeg
cd ffmpeg
for p in /tmp/mpvpatches/*.patch; do
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
git submodule update --init --depth 1 3rdparty/glad 3rdparty/jinja 3rdparty/markupsafe 3rdparty/Vulkan-Headers 3rdparty/fast_float
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

apt-get clean
rm -rf /var/lib/apt/lists/* /usr/src/* /root/build-mpv.sh
CHROOT_SCRIPT
    chmod +x "$ROOT/root/build-mpv.sh"
    mkdir -p "$ROOT/tmp/mpvpatches"
    cp patches/ffmpeg-v4l2request/*.patch "$ROOT/tmp/mpvpatches/"
    chroot "$ROOT" /root/build-mpv.sh
    [ -x "$ROOT/usr/local/bin/mpv" ] || { echo "mpv build failed" >&2; exit 1; }

    mkdir -p "$ROOT/usr/local/etc/mpv"
    printf 'hwdec=v4l2request\nvo=gpu-next\n' > "$ROOT/usr/local/etc/mpv/mpv.conf"

    (cd "$ROOT" && tar czf "/tmp/mpv-v4l2req.tar.gz" \
        usr/local/bin/mpv usr/local/etc/mpv/mpv.conf \
        usr/local/lib/libavcodec.so* usr/local/lib/libavformat.so* \
        usr/local/lib/libavutil.so* usr/local/lib/libswscale.so* \
        usr/local/lib/libswresample.so* usr/local/lib/libavfilter.so* \
        usr/local/lib/libpostproc.so*)
fi

rm -f "$ROOT/usr/bin/qemu-aarch64-static" "$ROOT/root/build-mpv.sh"

CLEANED=1
umount "$ROOT/dev/pts" 2>/dev/null || true
umount "$ROOT/proc" "$ROOT/sys" "$ROOT/dev" 2>/dev/null || true
umount "$ROOT"
losetup -d "$LOOP"
LOOP=""
trap - EXIT
echo "mpv (v4l2-request hwdec) installed into $IMG"

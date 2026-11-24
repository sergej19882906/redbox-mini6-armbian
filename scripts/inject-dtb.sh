#!/bin/bash
# Inject the Redbox Mini 6 (v1) DTB into a built Armbian .img
# Usage: sudo inject-dtb.sh /path/to/image.img
set -euo pipefail

IMG="$1"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DTB="$REPO_ROOT/dtb/sun50i-h6-redbox-mini6.dtb"
MNT=$(mktemp -d)
LOOP=""
CLEANED=0

cleanup() {
    [ "$CLEANED" -eq 1 ] && return 0
    umount "$MNT" 2>/dev/null || true
    if [ -n "$LOOP" ]; then
        losetup -d "$LOOP" 2>/dev/null || true
    fi
    return 0
}
trap cleanup EXIT

mount_first_part() {
    if LOOP=$(losetup -fP --show "$IMG" 2>/dev/null); then
        for i in $(seq 1 30); do
            [ -b "${LOOP}p1" ] && break
            partprobe "$LOOP" 2>/dev/null || true
            sleep 1
        done
        if [ -b "${LOOP}p1" ]; then
            mount "${LOOP}p1" "$MNT"
            echo "mounted via ${LOOP}p1"
            return 0
        fi
        losetup -d "$LOOP"
        LOOP=""
    fi
    START=$(sfdisk -d "$IMG" | grep -m1 'start=' | grep -o 'start= *[0-9]*' | tr -dc '0-9')
    [ -n "$START" ] || { echo "cannot find first partition in $IMG" >&2; return 1; }
    mount -o offset=$((START * 512)) "$IMG" "$MNT"
    echo "mounted via offset $START"
}

mount_first_part

cp -f "$DTB" "$MNT/boot/dtb/allwinner/"
for d in "$MNT"/usr/lib/linux-image-*/allwinner; do
    [ -d "$d" ] && cp -f "$DTB" "$d/"
done

ENV="$MNT/boot/armbianEnv.txt"
touch "$ENV"
sed -i '/^fdtfile=/d' "$ENV"
echo 'fdtfile=sun50i-h6-redbox-mini6.dtb' >> "$ENV"

CLEANED=1
umount "$MNT"
if [ -n "$LOOP" ]; then
    losetup -d "$LOOP" || true
    LOOP=""
fi
trap - EXIT
echo "DTB injected into $IMG"

#!/bin/bash
# Inject the Redbox Mini 6 (v1) DTB into a built Armbian .img
# Usage: sudo inject-dtb.sh /path/to/image.img
set -euo pipefail

IMG="$1"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DTB="$REPO_ROOT/dtb/sun50i-h6-redbox-mini6.dtb"
MNT=$(mktemp -d)

[ -b "$(losetup -f)" ] || { echo "no loop device available" >&2; exit 1; }
losetup -fP "$IMG"
LOOP=$(losetup -j "$IMG" | head -1 | cut -d: -f1)
trap 'umount "$MNT" 2>/dev/null; losetup -d "$LOOP" 2>/dev/null' EXIT

mount "${LOOP}p1" "$MNT"

cp -f "$DTB" "$MNT/boot/dtb/allwinner/"
for d in "$MNT"/usr/lib/linux-image-*/allwinner; do
    [ -d "$d" ] && cp -f "$DTB" "$d/"
done

ENV="$MNT/boot/armbianEnv.txt"
touch "$ENV"
sed -i '/^fdtfile=/d' "$ENV"
echo 'fdtfile=sun50i-h6-redbox-mini6.dtb' >> "$ENV"

umount "$MNT"
losetup -d "$LOOP"
trap - EXIT
echo "DTB injected into $IMG"

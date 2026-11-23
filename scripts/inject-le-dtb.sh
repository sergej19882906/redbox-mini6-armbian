#!/bin/bash
# Replace the Tanix TX6 DTB inside a built LibreELEC .img with the
# Redbox Mini 6 (v1) DTB (keeps the original filename so boot config works).
# Usage: sudo inject-le-dtb.sh /path/to/LibreELEC-...-tanix-tx6.img
set -euo pipefail

IMG="$1"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DTB="$REPO_ROOT/dtb/sun50i-h6-redbox-mini6.dtb"
MNT=$(mktemp -d)

losetup -fP "$IMG"
LOOP=$(losetup -j "$IMG" | head -1 | cut -d: -f1)
trap 'umount "$MNT" 2>/dev/null || true; losetup -d "$LOOP" 2>/dev/null || true' EXIT

mount "${LOOP}p1" "$MNT"

found=0
for f in "$MNT"/sun50i-h6*tanix*.dtb "$MNT"/*.dtb; do
    [ -f "$f" ] || continue
    cp -f "$DTB" "$f"
    found=1
done

if [ "$found" -eq 0 ]; then
    echo "no tanix dtb found in $IMG" >&2
    exit 1
fi

umount "$MNT"
losetup -d "$LOOP"
trap - EXIT
echo "Redbox Mini 6 DTB injected into $IMG"

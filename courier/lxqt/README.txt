# Reassemble redbox-mini6-lxqt-20261127.img.xz
cat redbox-mini6-lxqt-20261127.img.xz*.part-*' > redbox-mini6-lxqt-20261127.img.xz  # (in this folder: cat *.part-* > redbox-mini6-lxqt-20261127.img.xz)
sha256sum -c *.sha256
# then attach manually to release v1.0 (web UI) or: gh release upload v1.0 --clobber redbox-mini6-lxqt-20261127.img.xz

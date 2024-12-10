#!/bin/sh

ROM_DIR="$(dirname "$0")"
RA_DIR="/mnt/SDCARD/RetroArch"
CORE_DIR="$ROM_DIR/2048"

REMAP_SRC="$CORE_DIR/2048.rmp" 
REMAP_DST="$RA_DIR/.retroarch/config/remaps/2048/2048.rmp"
if ! [ -f "$REMAP_DST" ]; then
	cp "$REMAP_SRC" "$REMAP_DST"
fi

cd "$RA_DIR"
./retroarch -v -L "$CORE_DIR/2048_libretro.so"
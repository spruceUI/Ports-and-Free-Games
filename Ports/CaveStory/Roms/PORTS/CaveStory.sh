#!/bin/sh

ROM_DIR="$(dirname "$0")"
RA_DIR="/mnt/SDCARD/RetroArch"
CORE_DIR="$ROM_DIR/nxengine"

REMAP_SRC="$CORE_DIR/NXEngine.rmp" 
REMAP_DST="$RA_DIR/.retroarch/config/remaps/NXEngine/NXEngine.rmp"
if ! [ -f "$REMAP_DST" ]; then
	cp "$REMAP_SRC" "$REMAP_DST"
fi

cd "$RA_DIR"
./retroarch -v -L "$CORE_DIR/nxengine_libretro.so"
#!/bin/sh

ROM_DIR="$(dirname "$0")"
RA_DIR="/mnt/SDCARD/RetroArch"
DINO_DIR="$ROM_DIR/dinothawr"

REMAP_SRC="$CORE_DIR/Dinothawr.rmp" 
REMAP_DST="$RA_DIR/.retroarch/config/remaps/Dinothawr/Dinothawr.rmp"
if ! [ -f "$REMAP_DST" ]; then
	cp "$REMAP_SRC" "$REMAP_DST"
fi

cd "$RA_DIR"
./retroarch -v -L "$DINO_DIR/dinothawr_libretro.so" "$DINO_DIR/dinothawr.game"
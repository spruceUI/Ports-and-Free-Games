#!/bin/sh

ROM_DIR="$(dirname "$0")"
RA_DIR="/mnt/SDCARD/RetroArch"
DINO_DIR="$ROM_DIR/dinothawr"

cd "$RA_DIR"
./retroarch -v -L "$DINO_DIR/dinothawr_libretro.so" "$DINO_DIR/dinothawr.game"
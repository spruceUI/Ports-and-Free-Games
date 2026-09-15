#!/bin/sh

ROM_DIR="$(dirname "$0")"
RA_DIR="/mnt/SDCARD/RetroArch"
REMINISCENCE_DIR="$ROM_DIR/reminiscence"
CORE_DIR="$RA_DIR/.retroarch/cores"

cd "$RA_DIR"
./retroarch -v -L "$CORE_DIR/reminiscence_libretro.so" "$REMINISCENCE_DIR/level1.map"
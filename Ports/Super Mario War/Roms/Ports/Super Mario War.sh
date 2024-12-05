#!/bin/sh

ROM_DIR="$(dirname "$0")"
RA_DIR="/mnt/SDCARD/RetroArch"
SMW_DIR="$ROM_DIR/SuperMarioWar"
CORE_DIR="$RA_DIR/.retroarch/cores"

cd "$RA_DIR"
./retroarch -v -L "$CORE_DIR/superbroswar_libretro.so" "$SMW_DIR/Super Mario War.game"

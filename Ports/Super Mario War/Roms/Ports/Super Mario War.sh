#!/bin/sh

ROM_DIR="$(dirname "$0")"
RA_DIR="/mnt/SDCARD/RetroArch"
SMW_DIR="$ROM_DIR/SuperMarioWar"

cd "$RA_DIR"
./retroarch -v -L "$SMW_DIR/superbroswar_libretro.so" "$SMW_DIR/Super Mario War.game"

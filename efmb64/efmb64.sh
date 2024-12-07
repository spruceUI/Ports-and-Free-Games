#!/bin/sh

ROM_DIR="$(dirname "$0")"
RA_DIR="/mnt/SDCARD/RetroArch"
GAME_DIR="/mnt/SDCARD/Roms/PORTS/efmb64"
CORE_DIR="$RA_DIR/.retroarch/cores"

cd "$RA_DIR"

mv "./retroarch.cfg" "./retroarch.cfg.bak"
cp "./hotkeyprofile/retroarch.cfg" "./retroarch.cfg"

./ra32.miyoo -v -L "$CORE_DIR/vice_x64_libretro.so" "$GAME_DIR/efmb64.d64"

rm "./retroarch.cfg"
mv "./retroarch.cfg.bak" "./retroarch.cfg"
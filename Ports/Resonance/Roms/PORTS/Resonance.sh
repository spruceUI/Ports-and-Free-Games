#!/bin/sh

ROM_DIR="$(dirname "$0")"
RA_DIR="/mnt/SDCARD/RetroArch"
GAME_DIR="/mnt/SDCARD/Roms/SCUMMVM/Resonance"
CORE_DIR="$RA_DIR/.retroarch/cores"

cd "$RA_DIR"

./retroarch -v -L "$CORE_DIR/scummvm_libretro.so" "$GAME_DIR/Resonance.exe"

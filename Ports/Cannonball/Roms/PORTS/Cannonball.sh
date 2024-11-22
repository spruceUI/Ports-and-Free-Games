#!/bin/sh

ROM_DIR="$(dirname "$0")"
RA_DIR="/mnt/SDCARD/RetroArch"
CANNONBALL_DIR="$ROM_DIR/cannonball"
CORE_DIR="$RA_DIR/.retroarch/cores"

cd "$RA_DIR"
./retroarch -v -L "$CORE_DIR/cannonball_libretro.so" "$CANNONBALL_DIR/CannonBall.game"
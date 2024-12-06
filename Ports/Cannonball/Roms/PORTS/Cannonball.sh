#!/bin/sh

ROM_DIR="$(dirname "$0")"
RA_DIR="/mnt/SDCARD/RetroArch"
CANNONBALL_DIR="$ROM_DIR/cannonball"

cd "$RA_DIR"
./retroarch -v -L "$CANNONBALL_DIR/cannonball_libretro.so" "$CANNONBALL_DIR/CannonBall.game"
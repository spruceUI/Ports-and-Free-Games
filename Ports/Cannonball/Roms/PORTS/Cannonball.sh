#!/bin/sh

ROM_DIR="$(dirname "$0")"
RA_DIR="/mnt/SDCARD/RetroArch"
CANNONBALL_DIR="$ROM_DIR/cannonball"

OPT_SRC="$CANNONBALL_DIR/Cannonball.opt" 
OPT_DST="$RA_DIR/.retroarch/config/Cannonball/Cannonball.opt"
if ! [ -f "$OPT_DST" ]; then
	cp "$OPT_SRC" "$OPT_DST"
fi

cd "$RA_DIR"
./retroarch -v -L "$CANNONBALL_DIR/cannonball_libretro.so" "$CANNONBALL_DIR/CannonBall.game"
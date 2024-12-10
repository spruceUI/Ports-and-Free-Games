#!/bin/sh

ROM_DIR="$(dirname "$0")"
RA_DIR="/mnt/SDCARD/RetroArch"
CORE_DIR="$ROM_DIR/mrboom"

OPT_SRC="$CORE_DIR/Mr.Boom.opt" 
OPT_DST="$RA_DIR/.retroarch/config/Mr.Boom/Mr.Boom.opt"
if ! [ -f "$OPT_DST" ]; then
	cp "$OPT_SRC" "$OPT_DST"
fi

cd "$RA_DIR"
./retroarch -v -L "$CORE_DIR/mrboom_libretro.so"
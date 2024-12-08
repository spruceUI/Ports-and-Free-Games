#!/bin/sh

ROM_DIR="$(dirname "$0")"
OPENJAZZ_DIR="$ROM_DIR/openjazz"
LD_LIBRARY_PATH="$OPENJAZZ_DIR/lib:/mnt/SDCARD/miyoo/lib:$LD_LIBRARY_PATH"

cd "$OPENJAZZ_DIR"

# set stick to d-pad mode
killall -q -USR2 joystickinput

./OpenJazz jazz jazzxmas

# set stick to analog mode
killall -q -USR1 joystickinput
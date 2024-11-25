#!/bin/sh

ROM_DIR="$(dirname "$0")"
OPENJAZZ_DIR="$ROM_DIR/openjazz"
LD_LIBRARY_PATH="$OPENJAZZ_DIR/lib:/mnt/SDCARD/miyoo/lib:$LD_LIBRARY_PATH"

cd "$OPENJAZZ_DIR"

./OpenJazz jazz jazzxmas
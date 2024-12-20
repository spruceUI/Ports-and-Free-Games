#!/bin/sh

ROM_DIR="$(dirname "$0")"
GAME_DIR="$ROM_DIR/labbaye"
LD_LIBRARY_PATH="/mnt/SDCARD/miyoo/lib:$LD_LIBRARY_PATH"
export XDG_DATA_HOME="$GAME_DIR:$XDG_DATA_HOME"
export DATADIR="$GAME_DIR"
cd "$GAME_DIR"

# set stick to d-pad mode
killall -q -USR2 joystickinput

./abbayev2

# set stick to analog mode
killall -q -USR1 joystickinput
#!/bin/sh

ROM_DIR="$(dirname "$0")"
GAMEDIR="$ROM_DIR/rocks"
export LD_LIBRARY_PATH="$GAMEDIR/lib:$LD_LIBRARY_PATH"
export HOME="/mnt/SDCARD/Saves" # store scores in saves dir

cd "$GAMEDIR"

# set stick to d-pad mode
killall -q -USR2 joystickinput

./rocksndiamonds

# set stick to analog mode
killall -q -USR1 joystickinput
#!/bin/sh

ROM_DIR="$(dirname "$0")"
GAMEDIR="$ROM_DIR/digger"
export LD_LIBRARY_PATH="$GAMEDIR/lib:/mnt/SDCARD/miyoo/lib:$LD_LIBRARY_PATH"
cd "$GAMEDIR"


# set stick to d-pad mode
killall -q -USR2 joystickinput

./digger

# set stick to analog mode
killall -q -USR1 joystickinput

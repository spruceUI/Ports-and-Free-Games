#!/bin/sh

ROM_DIR="$(dirname "$0")"
NKARUGA_DIR="$ROM_DIR/nkaruga"
LD_LIBRARY_PATH="$NKARUGA_DIR/lib:/mnt/SDCARD/miyoo/lib:$LD_LIBRARY_PATH"

cd "$NKARUGA_DIR"

# set stick to d-pad mode
killall -q -USR2 joystickinput

./nKaruga.elf

# set stick to analog mode
killall -q -USR1 joystickinput
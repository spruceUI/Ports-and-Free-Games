#!/bin/sh

ROM_DIR="$(dirname "$0")"
HCL_DIR="$ROM_DIR/hydracastlelabyrinth"

export HOME="$HCL_DIR"
export LD_LIBRARY_PATH="/mnt/SDCARD/miyoo/lib:$LD_LIBRARY_PATH"

cd "$HCL_DIR"

# set stick to d-pad mode
killall -q -USR2 joystickinput

./hcl

# set stick to analog mode
killall -q -USR1 joystickinput
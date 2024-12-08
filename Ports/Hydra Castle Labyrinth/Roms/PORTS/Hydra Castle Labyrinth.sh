#!/bin/sh

ROM_DIR="$(dirname "$0")"
HCL_DIR="$ROM_DIR/hydracastlelabyrinth"
export LD_LIBRARY_PATH="/mnt/SDCARD/miyoo/lib:$LD_LIBRARY_PATH"
cd "$HCL_DIR"

./hcl

#!/bin/sh

ROM_DIR="$(dirname "$0")"
NKARUGA_DIR="$ROM_DIR/nkaruga"
LD_LIBRARY_PATH="$NKARUGA_DIR/lib:/mnt/SDCARD/miyoo/lib:$LD_LIBRARY_PATH"

cd "$NKARUGA_DIR"

./nKaruga.elf
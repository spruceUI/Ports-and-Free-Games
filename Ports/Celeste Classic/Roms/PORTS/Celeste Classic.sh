#!/bin/sh

ROM_DIR="$(dirname "$0")"
GAMEDIR="$ROM_DIR/ccleste"

cd "$GAMEDIR"

# set stick to d-pad mode
killall -q -USR2 joystickinput

./ccleste

# set stick to analog mode
killall -q -USR1 joystickinput
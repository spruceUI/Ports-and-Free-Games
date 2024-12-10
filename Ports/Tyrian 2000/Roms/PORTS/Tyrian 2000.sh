#!/bin/sh

ROM_DIR="$(dirname "$0")"
GAME_DIR="$ROM_DIR/opentyrian2000"
export XDG_CONFIG_HOME="$ROM_DIR"

cd "$GAME_DIR"

# set stick to d-pad mode
killall -q -USR2 joystickinput

./opentyrian2000 -t "gamedata" -j

# set stick to analog mode
killall -q -USR1 joystickinput
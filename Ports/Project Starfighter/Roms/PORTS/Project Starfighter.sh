#!/bin/sh

ROM_DIR="$(dirname "$0")"
GAME_DIR="$ROM_DIR/starfighter"
export XDG_CONFIG_HOME="$ROM_DIR/.config/"
export LD_LIBRARY_PATH="$GAME_DIR/lib:$LD_LIBRARY_PATH"

cd "$GAME_DIR"

# set stick to d-pad mode
killall -q -USR2 joystickinput

./starfighter 

# set stick to analog mode
killall -q -USR1 joystickinput
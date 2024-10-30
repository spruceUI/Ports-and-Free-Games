#!/bin/sh
mydir=`pwd`
export LD_LIBRARY_PATH="$mydir"/lib:$LD_LIBRARY_PATH
export SDL_VIDEODRIVER=a30
export SDL_JOYSTICKDRIVER=a30


while :; do
    syncsettings.elf
done &
LOOP_PID=$!

cd "$mydir"
./RSDKv5U

kill $LOOP_PID
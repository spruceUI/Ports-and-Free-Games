#!/bin/sh
# Aesthetic Spruce launcher (spruceOS). PyUI has already exited when this runs (principal.sh
# executes /tmp/cmd_to_run.sh and restarts the frontend when we return), so the app owns the
# display for its lifetime and "apply theme" is just writing the "theme" key and exiting.
. /mnt/SDCARD/spruce/scripts/helperFunctions.sh

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$APP_DIR/.aesthetic"
USERDATA_DIR="$APP_DIR/userdata"
LOG_DIR="$USERDATA_DIR/logs"
mkdir -p "$LOG_DIR" "$USERDATA_DIR/presets"
SESSION_LOG_FILE="$LOG_DIR/$(date +%Y%m%d_%H%M%S).log"
# keep the last few sessions only (FAT cards fill up with logs otherwise)
ls -1t "$LOG_DIR"/*.log 2>/dev/null | tail -n +6 | xargs -r rm -f

log_message "Aesthetic Spruce: starting on $PLATFORM (${DISPLAY_WIDTH}x${DISPLAY_HEIGHT} rot ${DISPLAY_ROTATION:-0})"

export WIDTH="$DISPLAY_WIDTH"
export HEIGHT="$DISPLAY_HEIGHT"
export ROTATION="${DISPLAY_ROTATION:-0}"
export ROOT_DIR="$APP_DIR"
export SOURCE_DIR
export THEME_PRESETS_DIR="$SOURCE_DIR/presets"
export SESSION_LOG_FILE
export SPRUCE_PLATFORM="$PLATFORM"
export SPRUCE_SYSTEM_JSON="$SYSTEM_JSON"
export SPRUCE_THEMES_DIR="/mnt/SDCARD/Themes"
# version for the in-app compatibility warning (src/spruce/compat.lua)
export SPRUCE_VERSION="$(get_version 2>/dev/null)"
export SPRUCE_VERSION_COMPLEX="$(get_version_complex 2>/dev/null)"

# liblove/luajit ship with the app and must win; the LÖVE media libraries come from the stock
# rootfs where present (verified on TrimUI Smart Pro S and Miniloong) and from lib/fallback
# only when a device lacks them, so the fallback goes LAST.
export LD_LIBRARY_PATH="$SOURCE_DIR/lib:$LD_LIBRARY_PATH:$SOURCE_DIR/lib/fallback"

# SDL video/audio per platform, mirroring App/PyUI/launch.sh (PyUI is the reference SDL app).
case "$PLATFORM" in
    Miniloong | RGB30)
        export SDL_VIDEODRIVER=kmsdrm
        export SDL_AUDIODRIVER=alsa
        ;;
    Anbernic*)
        export SDL_JOYSTICK_DISABLE_UDEV=1
        if [ -f /mnt/SDCARD/App/PyUI/dll-mali/libSDL2-2.0.so.0 ]; then
            export LD_LIBRARY_PATH="/mnt/SDCARD/App/PyUI/dll-mali:$LD_LIBRARY_PATH"
            export SDL_VIDEODRIVER=mali
        fi
        ;;
esac

# Gamepad mapping: TrimUI and Miniloong pads carry built-in SDL mappings; Anbernic and RGB30
# pads need the map spruce defines per platform.
export_sdl_gamecontroller_map

# Button labels: SDL's built-in maps are positional (bottom = "a"), these devices print Nintendo
# labels (right = A). Same facts PyUI uses in its per-device evdev tables
# (App/PyUI/main-ui/devices/*mapping_provider*.py); spruce's own Anbernic/RGB30 maps are label-based.
# The MagicX ones are NOT: their platform cfgs export a:b0,b:b1,x:b2,y:b3 over a pad that emits the
# face buttons positionally (304 south, 305 east, 307 north, 308 west), and PyUI's own table reads
# 305=A 304=B 308=X 307=Y, so SDL's a/x land on the buttons labelled B/Y. Measured on a Zero 40.
case "$PLATFORM" in
    Brick | BrickPro | SmartPro | SmartProS | Flip | Zero28 | Zero40 | XU20)
        export AESTHETIC_SWAP_AB=1 AESTHETIC_SWAP_XY=1 ;;   # 304->B 305->A 307->Y 308->X
    Miniloong | Pixel2)
        export AESTHETIC_SWAP_AB=1 ;;                       # 304->B 305->A, X/Y already in place
esac

echo 1 > /tmp/stay_awake
cd "$SOURCE_DIR" || exit 1
chmod +x ./bin/love 2>/dev/null
./bin/love . >> "$SESSION_LOG_FILE" 2>&1
EXIT_CODE=$?
rm -f /tmp/stay_awake
if [ "$EXIT_CODE" != 0 ] && [ -f "$USERDATA_DIR/last_crash.txt" ] && [ "$USERDATA_DIR/last_crash.txt" -nt "$SESSION_LOG_FILE" ]; then
    log_message "Aesthetic Spruce crashed: $(sed -n 2p "$USERDATA_DIR/last_crash.txt" | cut -c1-200)"
fi
log_message "Aesthetic Spruce: exited with $EXIT_CODE"
exit 0

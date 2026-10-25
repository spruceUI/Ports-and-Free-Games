#!/bin/sh
# zitch, itch.io's handheld frontend, from spruceUI/zitch. It draws through
# the device's own libSDL2, so each platform points it at the SDL build PyUI
# uses there, as Cheevos does.

. /mnt/SDCARD/spruce/scripts/helperFunctions.sh

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="/mnt/SDCARD/Saves/spruce/zitch-$PLATFORM.log"
# A game can't share the screen with zitch, so zitch writes what to run here
# and exits; it runs below, then zitch comes back.
HANDOFF=/tmp/zitch_next.sh
# Each 32-bit device has a build of its own; the rest share the aarch64 one.
case "$PLATFORM" in
    "A30") BIN_DIR="$APP_DIR/zitch-a30" ;;
    "MiyooMini") BIN_DIR="$APP_DIR/zitch-mini" ;;
    *) BIN_DIR="$APP_DIR/zitch" ;;
esac

# zitch's environment only: the games it hands over run with spruce's.
zitch_env() {
    case "$PLATFORM" in
        "Flip")
            export LD_LIBRARY_PATH="/mnt/SDCARD/App/PyUI/dll:$LD_LIBRARY_PATH"
            ;;
        "Brick" | "BrickPro" | "SmartPro" | "SmartProS")
            export LD_LIBRARY_PATH="/mnt/SDCARD/spruce/brick/sdl2:$LD_LIBRARY_PATH"
            ;;
        "AnbernicXX"* | "AnbernicRG28XX" | "AnbernicRGCubeXX")
            PYUI_DLL=/mnt/SDCARD/App/PyUI/dll
            [ -f /mnt/SDCARD/App/PyUI/dll-mali/libSDL2-2.0.so.0 ] && PYUI_DLL=/mnt/SDCARD/App/PyUI/dll-mali
            export LD_LIBRARY_PATH="$PYUI_DLL:/mnt/SDCARD/spruce/flip/lib:/usr/lib"
            export SDL_JOYSTICK_DISABLE_UDEV=1
            case "$PYUI_DLL" in
                *dll-mali) export SDL_VIDEODRIVER=mali ;;
            esac
            ;;
        "Pixel2")
            export LD_LIBRARY_PATH="/usr/lib:$LD_LIBRARY_PATH"
            ;;
        "A30")
            export LD_LIBRARY_PATH="/usr/miyoo/lib:$LD_LIBRARY_PATH"
            export SDL_VIDEODRIVER=mali
            # The firmware's joypad spoofs an Xbox 360 pad, so SDL would apply
            # its Xbox mapping; this is MIYOO Pad1's own, as ScummVM uses it.
            export SDL_GAMECONTROLLERCONFIG="030000005e0400008e0200005e040000,MIYOO Pad1,a:b0,b:b1,x:b3,y:b2,leftshoulder:b4,rightshoulder:b5,back:b6,start:b7,guide:b8,leftstick:b9,rightstick:b10,leftx:a0,lefty:a1,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,platform:Linux,"
            # The buttons are keys too; read through the pad, each press would act twice.
            export ZITCH_IGNORE_KEYBOARD=1
            # The panel is mounted on its side; zitch turns its frame as PyUI does.
            export ZITCH_SCREEN_ROTATION="$DISPLAY_ROTATION"
            ;;
        "MiyooMini")
            # PyUI's SDL2. Its GL is SwiftShader, too slow for egui, so zitch
            # draws on the CPU and shows frames through SDL's 2D renderer.
            export PATH="/mnt/SDCARD/spruce/miyoomini/bin:$PATH"
            export LD_LIBRARY_PATH="/mnt/SDCARD/spruce/miyoomini/lib:$LD_LIBRARY_PATH"
            export SDL_VIDEODRIVER=mmiyoo
            export SDL_AUDIODRIVER=mmiyoo
            export SDL_MMIYOO_DOUBLE_BUFFER=1
            export ZITCH_SOFT_RENDER=1
            export ZITCH_KEYPAD=miyoo
            ;;
        "Zero28" | "Zero40" | "XU20")
            LD_LIBRARY_PATH="$(magicx_pyui_sdl_dir):$LD_LIBRARY_PATH"
            export LD_LIBRARY_PATH
            ;;
        "Miniloong" | "RGB30" | "RGB20SX" | "A10Mini" | "A10MiniV4" | "XUMiniM" | "G350" | "V10")
            # dArkMoss's own SDL2 2.32 (KMSDRM, Mali GLES).
            export LD_LIBRARY_PATH="/usr/lib/aarch64-linux-gnu:$LD_LIBRARY_PATH"
            export SDL_VIDEODRIVER=kmsdrm
            export SDL_AUDIODRIVER=alsa
            ;;
        *)
            return 1
            ;;
    esac

    # The login, butler's database and downloaded games live in Saves,
    # which updates never touch.
    HOME="/mnt/SDCARD/Saves/zitch"
    XDG_CONFIG_HOME="$HOME/.config"
    XDG_CACHE_HOME="$HOME/.cache"
    export HOME XDG_CONFIG_HOME XDG_CACHE_HOME
    mkdir -p "$HOME"

    export_sdl_gamecontroller_map positional
    # spruce devices are labelled the Nintendo way: A right, B bottom.
    export ZITCH_NINTENDO_BUTTONS=1
    export SSL_CERT_FILE=/mnt/SDCARD/spruce/etc/ca-certificates.crt
}

if ! (zitch_env); then
    /mnt/SDCARD/App/PyUI/launch.sh -msgDisplay "itch.io doesn't support this device ($PLATFORM) yet." -msgDisplayTimeMs 5000
    exit 1
fi

chmod +x "$BIN_DIR/zitch" "$BIN_DIR/butler"

: >"$LOG"

while :; do
    rm -f "$HANDOFF"
    # Downloads run long; idle sleep would cut them off.
    echo 1 > /tmp/stay_awake
    (
        zitch_env
        cd "$BIN_DIR" || exit 1
        # The graphics memory the menu or a game left behind.
        [ "$PLATFORM" = "MiyooMini" ] && freemma >/dev/null 2>&1
        ./zitch --fullscreen --low-spec --butler "$BIN_DIR/butler"
    ) >>"$LOG" 2>&1
    rm -f /tmp/stay_awake
    [ -s "$HANDOFF" ] || break
    log_message "zitch: running $(cat "$HANDOFF")"
    case "$PLATFORM" in
        "MiyooMini")
            # As PyUI starts a game: libpadsp takes its sound to audioserver.
            preload=/mnt/SDCARD/miyoo/lib/libpadsp.so
            [ -f "$preload" ] || preload=/customer/lib/libpadsp.so
            LD_PRELOAD="$preload" sh "$HANDOFF"
            ;;
        *)
            sh "$HANDOFF"
            ;;
    esac
done

rm -f "$HANDOFF"

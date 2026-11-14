#!/bin/sh

# shellcheck shell=sh
set -eu

if [ "${RETROSHELF_LAUNCHER_RELOCATED:-}" = "1" ]; then
  DIR="$RETROSHELF_LAUNCHER_DIR"
  trap 'rm -f "$RETROSHELF_LAUNCHER_TEMP"' 0
else
  DIR="$(CDPATH='' cd "$(dirname "$0")" && pwd)"
  export RETROSHELF_LAUNCHER_DIR="$DIR"
  RETROSHELF_LAUNCHER_TEMP=""
  if RETROSHELF_LAUNCHER_TEMP="$(umask 077; mktemp "${TMPDIR:-/tmp}/retroshelf-launch.XXXXXX" 2>/dev/null)" &&
    cp -f "$0" "$RETROSHELF_LAUNCHER_TEMP" 2>/dev/null; then
    export RETROSHELF_LAUNCHER_TEMP
    export RETROSHELF_LAUNCHER_RELOCATED=1
    if exec /bin/sh "$RETROSHELF_LAUNCHER_TEMP"; then
      exit 0
    fi
    unset RETROSHELF_LAUNCHER_RELOCATED
  fi
  [ -z "$RETROSHELF_LAUNCHER_TEMP" ] || rm -f "$RETROSHELF_LAUNCHER_TEMP"
  unset RETROSHELF_LAUNCHER_TEMP
  export RETROSHELF_LAUNCHER_OPEN=1
fi
cd "$DIR" || exit 1

if [ "${RETROSHELF_LAUNCHER_OPEN:-}" != "1" ] && [ -d "$DIR/.update" ]; then
  if ! "$DIR/retroshelf-sync" update apply >/dev/null 2>&1; then
    RETROSHELF_STAGED_ENGINE_KIND="spruce"
    case "$RETROSHELF_STAGED_ENGINE_KIND" in
      direct)
        STAGED_ENGINE_SOURCE="$DIR/.update/retroshelf-sync"
        ;;
      spruce)
        case "${PLATFORM:-MiyooMini}" in
          A30|MiyooMini)
            STAGED_ENGINE_SOURCE="$DIR/.update/retroshelf-sync32"
            ;;
          *)
            STAGED_ENGINE_SOURCE="$DIR/.update/retroshelf-sync64"
            ;;
        esac
        ;;
    esac

    # Copy outside .update before Apply consumes it. Running a staged binary
    # from inside the stage can leave FUSE hidden files that block cleanup.
    STAGED_ENGINE="$DIR/.update-engine.$$"
    rm -f "$STAGED_ENGINE"
    if cp -f "$STAGED_ENGINE_SOURCE" "$STAGED_ENGINE" 2>/dev/null && chmod 755 "$STAGED_ENGINE" 2>/dev/null; then
      "$STAGED_ENGINE" update apply --engine-path "$DIR/retroshelf-sync" >/dev/null 2>&1 || true
    fi
    rm -f "$STAGED_ENGINE"
  fi
fi

export CFW=SPRUCE

PLATFORM="${PLATFORM:-}"
if [ -z "$PLATFORM" ]; then
  PLATFORM="MiyooMini"
  export PLATFORM
fi

case "$PLATFORM" in
  A30)
    export SPRUCE_DEVICE=A30
    APP="$DIR/retroshelf-app32"
    LIB="/mnt/SDCARD/spruce/a30/sdl2:$DIR/lib32-a30"
    ;;
  MiyooMini)
    export SPRUCE_DEVICE=MIYOOMINI IS_MIYOO=1 SDL_VIDEODRIVER=mmiyoo SDL_AUDIODRIVER=mmiyoo EGL_VIDEODRIVER=mmiyoo SDL_MMIYOO_DOUBLE_BUFFER=1
    APP="$DIR/retroshelf-app32"
    LIB="$DIR/lib32-miyoo"
    ;;
  Brick|BrickPro|SmartPro|SmartProS)
    export SPRUCE_DEVICE=TRIMUI
    APP="$DIR/retroshelf-app64"
    LIB="$DIR/lib64"
    ;;
  Pixel2)
    export SPRUCE_DEVICE=PIXEL
    APP="$DIR/retroshelf-app64"
    LIB="$DIR/lib64"
    ;;
  Flip)
    export SPRUCE_DEVICE=MIYOOFLIP
    APP="$DIR/retroshelf-app64"
    LIB="$DIR/lib64"
    ;;
  Zero28|Zero40|XU20|AnbernicRG28XX|AnbernicRGCubeXX|AnbernicXX*)
    APP="$DIR/retroshelf-app64"
    LIB="$DIR/lib64"
    ;;
  *)
    warning="Unknown Spruce platform: '${PLATFORM:-<empty>}'"
    echo "$warning" >&2
    echo "$warning" >> "$DIR/retroshelf.log" 2>/dev/null || true
    APP="$DIR/retroshelf-app64"
    LIB="$DIR/lib64"
    ;;
esac

while :; do
  "$DIR/retroshelf-sync" hooks repair >/dev/null 2>&1 || true
  if LD_LIBRARY_PATH="$LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$APP"; then
    status=0
  else
    status=$?
  fi
  [ "$status" -eq 75 ] || exit "$status"
done

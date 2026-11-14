#!/bin/sh
# Transitional compatibility shim for legacy SpruceOS hooks; remove after one release.
set -eu

SOURCE="manual"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --source)
      if [ "$#" -gt 1 ]; then
        SOURCE="$2"
        shift 2
      else
        shift
      fi
      ;;
    *) shift ;;
  esac
done

case "$SOURCE" in
  *startup*) TRIGGER="startup" ;;
  *checkoff*|*shutdown*) TRIGGER="shutdown" ;;
  *game-exit*|*postprocess*) TRIGGER="game-exit" ;;
  *) TRIGGER="manual" ;;
esac

APPDIR="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
export CFW=SPRUCE
exec "$APPDIR/retroshelf-sync" run --trigger="$TRIGGER"

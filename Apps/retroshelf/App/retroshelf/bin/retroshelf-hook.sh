#!/bin/sh
# Transitional compatibility shim for legacy SpruceOS game-exit hooks; remove after one release.
set -eu

APPDIR="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
export CFW=SPRUCE
"$APPDIR/retroshelf-sync" run --trigger=game-exit &
exit 0

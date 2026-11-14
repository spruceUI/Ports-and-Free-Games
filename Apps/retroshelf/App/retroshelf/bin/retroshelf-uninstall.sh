#!/bin/sh
# Remove hooks persisted outside the app before deleting it.
set -eu

APPDIR="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
export CFW=SPRUCE
exec "$APPDIR/retroshelf-sync" uninstall "$@"

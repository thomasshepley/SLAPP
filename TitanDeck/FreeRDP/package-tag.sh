#!/usr/bin/env bash
# Prints the release tag for the current FreeRDPKit recipe: the FreeRDP version
# plus a short hash of this folder's build inputs, so any change gets a new tag.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=versions.env
source "$HERE/versions.env"
HASH=$(cat "$HERE/versions.env" "$HERE/build.sh" | shasum -a 256 | cut -c1-10)
echo "freerdpkit-$FREERDP_VERSION-$HASH"

#!/usr/bin/env bash
# Downloads the prebuilt FreeRDPKit for this recipe into TitanDeck/Vendor.
# Run once after cloning, and again whenever this folder changes (the project
# won't build without it). CI builds and publishes the package automatically.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
VENDOR="$HERE/../Vendor"
TAG="$("$HERE/package-tag.sh")"
REPO="${TITANDECK_REPO:-thomasshepley/SLAPP}"

if [ -f "$VENDOR/.freerdpkit-tag" ] && [ "$(cat "$VENDOR/.freerdpkit-tag")" = "$TAG" ] \
    && [ -d "$VENDOR/FreeRDPKit.xcframework" ]; then
    echo "FreeRDPKit $TAG already present."
    exit 0
fi

echo "Downloading FreeRDPKit $TAG..."
mkdir -p "$VENDOR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
if ! curl -fSL -o "$TMP/FreeRDPKit.zip" \
    "https://github.com/$REPO/releases/download/$TAG/FreeRDPKit.zip"; then
    echo "Package $TAG isn't published yet. It's built by the TitanDeck workflow on GitHub -" >&2
    echo "wait for that run to finish, or build it locally with ./build.sh (30-60 min)." >&2
    exit 1
fi
rm -rf "$VENDOR/FreeRDPKit.xcframework" "$VENDOR/FreeRDPHeaders"
unzip -q "$TMP/FreeRDPKit.zip" -d "$VENDOR"
echo "$TAG" > "$VENDOR/.freerdpkit-tag"
echo "FreeRDPKit $TAG installed in TitanDeck/Vendor."

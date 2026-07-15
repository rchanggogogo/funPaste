#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
version="0.0.0-test"
app="$project_dir/dist/funPaste.app"
dmg="$project_dir/dist/funPaste-$version.dmg"

rm -rf "$app" "$dmg"
bash "$project_dir/scripts/build-dmg.sh" "$version"

[[ -f "$dmg" ]]
[[ -x "$app/Contents/MacOS/funPaste" ]]

architectures="$(lipo -archs "$app/Contents/MacOS/funPaste")"
[[ "$architectures" == *arm64* ]]
[[ "$architectures" == *x86_64* ]]

codesign --verify --deep --strict --verbose=2 "$app"
hdiutil imageinfo "$dmg" >/dev/null


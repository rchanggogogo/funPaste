#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
version="${1:-1.0.0}"
dist_dir="$project_dir/dist"
arm_build="$project_dir/.build-release-arm64"
intel_build="$project_dir/.build-release-x86_64"
universal_binary="$dist_dir/funPaste-universal"
app="$dist_dir/funPaste.app"
dmg="$dist_dir/funPaste-$version.dmg"
stage_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$stage_dir"
}
trap cleanup EXIT

rm -rf "$app" "$universal_binary" "$dmg"
mkdir -p "$dist_dir"

swift build -c release --product FunPastePreview --arch arm64 --build-path "$arm_build"
swift build -c release --product FunPastePreview --arch x86_64 --build-path "$intel_build"

arm_binary="$arm_build/arm64-apple-macosx/release/FunPastePreview"
intel_binary="$intel_build/x86_64-apple-macosx/release/FunPastePreview"

lipo -create "$arm_binary" "$intel_binary" -output "$universal_binary"
lipo "$universal_binary" -verify_arch arm64 x86_64

FUNPASTE_EXECUTABLE_PATH="$universal_binary" \
FUNPASTE_VERSION="$version" \
  bash "$project_dir/scripts/build-app.sh"

codesign --verify --deep --strict --verbose=2 "$app"
cp -R "$app" "$stage_dir/funPaste.app"
ln -s /Applications "$stage_dir/Applications"
hdiutil create \
  -volname "funPaste" \
  -srcfolder "$stage_dir" \
  -ov \
  -format UDZO \
  "$dmg"

echo "已创建通用安装包：$dmg"

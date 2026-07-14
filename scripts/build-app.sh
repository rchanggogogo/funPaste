#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$project_dir/dist/funPaste.app"
contents_dir="$app_dir/Contents"
info_plist="$contents_dir/Info.plist"

bash "$project_dir/scripts/make-icon.sh"

cd "$project_dir"
swift build -c release --product FunPastePreview

mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$project_dir/.build/release/FunPastePreview" "$contents_dir/MacOS/funPaste"
chmod +x "$contents_dir/MacOS/funPaste"
cp "$project_dir/Assets/AppIcon/AppIcon.icns" "$contents_dir/Resources/AppIcon.icns"

plutil -create xml1 "$info_plist"
plutil -replace CFBundleName -string "funPaste" "$info_plist"
plutil -replace CFBundleDisplayName -string "funPaste" "$info_plist"
plutil -replace CFBundleIdentifier -string "com.changlei.funPaste" "$info_plist"
plutil -replace CFBundleExecutable -string "funPaste" "$info_plist"
plutil -replace CFBundleIconFile -string "AppIcon" "$info_plist"
plutil -replace CFBundlePackageType -string "APPL" "$info_plist"
plutil -replace CFBundleShortVersionString -string "1.0.0" "$info_plist"
plutil -replace CFBundleVersion -string "1" "$info_plist"
plutil -replace LSMinimumSystemVersion -string "14.0" "$info_plist"
plutil -replace NSHighResolutionCapable -bool true "$info_plist"
plutil -replace LSUIElement -bool true "$info_plist"

if [[ -n "${FUNPASTE_CODESIGN_IDENTITY:-}" ]]; then
  codesign \
    --force \
    --sign "$FUNPASTE_CODESIGN_IDENTITY" \
    --identifier "com.changlei.funPaste" \
    "$app_dir"
else
  codesign \
    --force \
    --sign - \
    --identifier "com.changlei.funPaste" \
    --requirements '=designated => identifier "com.changlei.funPaste"' \
    "$app_dir"
fi

codesign --verify --deep --strict --verbose=2 "$app_dir"

echo "已构建应用：$app_dir"

#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
assets_dir="$project_dir/Assets/AppIcon"
source_icon="$assets_dir/app-icon-1024.png"
iconset_dir="$assets_dir/AppIcon.iconset"
output_icon="$assets_dir/AppIcon.icns"

if [[ ! -f "$source_icon" ]]; then
  echo "未找到图标源文件：$source_icon" >&2
  exit 1
fi

mkdir -p "$iconset_dir"

generate_size() {
  local size="$1"
  local filename="$2"
  sips -z "$size" "$size" "$source_icon" --out "$iconset_dir/$filename" >/dev/null
}

generate_size 16 icon_16x16.png
generate_size 32 icon_16x16@2x.png
generate_size 32 icon_32x32.png
generate_size 64 icon_32x32@2x.png
generate_size 128 icon_128x128.png
generate_size 256 icon_128x128@2x.png
generate_size 256 icon_256x256.png
generate_size 512 icon_256x256@2x.png
generate_size 512 icon_512x512.png
generate_size 1024 icon_512x512@2x.png

iconutil -c icns "$iconset_dir" -o "$output_icon"
echo "已生成 macOS 图标：$output_icon"

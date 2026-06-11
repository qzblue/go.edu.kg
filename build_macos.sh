#!/usr/bin/env bash
# 在 macOS 上一键打双架构 dmg：M 芯片(arm64) + Intel(amd64)
# 详细前置依赖见 macos/BUILD_macOS.md
set -euo pipefail
cd "$(dirname "$0")"

VER="v1.0"
OUT="out"
mkdir -p "$OUT"

echo "==> flutter pub get"
flutter pub get

build_one() {
  local arch="$1" label="$2"
  echo "==> 构建 $label ($arch) dmg"
  rm -f dist/*.dmg 2>/dev/null || true
  dart setup.dart macos --arch "$arch" --env pre
  local dmg
  dmg="$(ls -t dist/*.dmg | head -1)"
  cp "$dmg" "$OUT/美国华人华侨贸易中心_${VER}_macOS_${label}.dmg"
  echo "   -> $OUT/美国华人华侨贸易中心_${VER}_macOS_${label}.dmg"
}

build_one arm64 AppleSilicon   # M 芯片
build_one amd64 Intel          # Intel

echo "==> 完成"
ls -lh "$OUT"/*.dmg

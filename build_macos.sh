#!/usr/bin/env bash
# 在 macOS 上打 **Universal 通用包**（一个 dmg 同时含 arm64+x86_64，M 芯片与 Intel 都原生运行）。
# 可在 Intel Mac 上构建（arm64 部分为交叉编译）。详见 macos/BUILD_macOS.md
set -euo pipefail
cd "$(dirname "$0")"

VER="v1.0"
OUT="out"
TAGS="with_gvisor"          # 与 setup.dart 保持一致
DIST_PLUGIN="plugins/flutter_distributor/packages/flutter_distributor"
mkdir -p "$OUT" libclash/macos

# —— 依赖检查 ——
for c in go lipo flutter dart; do
  command -v "$c" >/dev/null 2>&1 || { echo "缺少依赖: $c"; exit 1; }
done

echo "==> 1/4 交叉编译双架构内核 FlClashCore (CGO 关，纯 Go)"
( cd core
  GOOS=darwin GOARCH=arm64 CGO_ENABLED=0 go build -ldflags="-w -s" -tags="$TAGS" -o ../libclash/macos/FlClashCore_arm64
  GOOS=darwin GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-w -s" -tags="$TAGS" -o ../libclash/macos/FlClashCore_amd64 )

echo "==> 2/4 lipo 合并为 Universal 内核"
lipo -create libclash/macos/FlClashCore_arm64 libclash/macos/FlClashCore_amd64 -output libclash/macos/FlClashCore
rm -f libclash/macos/FlClashCore_arm64 libclash/macos/FlClashCore_amd64
lipo -info libclash/macos/FlClashCore     # 应显示: arm64 x86_64

echo "==> 3/4 准备 env.json + 依赖 + flutter_distributor"
echo '{"APP_ENV":"pre","CORE_SHA256":""}' > env.json
flutter pub get
dart pub global activate -s path "$DIST_PLUGIN" >/dev/null

echo "==> 4/4 构建 Universal .app 并打 dmg"
# release 构建的 .app 主程序本就是 arm64+x86_64 universal；这里它会捆绑上面 lipo 的 universal 内核
flutter_distributor package --platform macos --targets dmg \
  --flutter-build-args=dart-define-from-file=env.json --skip-clean

dmg="$(find dist -name '*.dmg' -type f -exec ls -t {} + 2>/dev/null | head -1)"
[ -n "${dmg:-}" ] || { echo "未找到生成的 dmg"; exit 1; }
cp "$dmg" "$OUT/美国华人华侨贸易中心_${VER}_macOS_Universal.dmg"

echo
echo "==> 完成: $OUT/美国华人华侨贸易中心_${VER}_macOS_Universal.dmg"
echo "    校验主程序架构:"
APP="$(find build/macos -maxdepth 5 -name '*.app' -type d | head -1)"
[ -n "${APP:-}" ] && lipo -info "$APP/Contents/MacOS/"* 2>/dev/null || true

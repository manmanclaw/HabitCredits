#!/usr/bin/env bash
# 在仓库根目录执行：生成 Release 版 HabitCredits.app 并打成 zip，便于上传到 GitHub Releases。
# 用法: ./scripts/package-release.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT="HabitCredits.xcodeproj"
SCHEME="HabitCredits"
CONFIG="Release"
DERIVED="$ROOT/build/DerivedData"
OUT="$ROOT/dist"
APP_NAME="HabitCredits.app"
ZIP_NAME="HabitCredits-macOS.zip"

rm -rf "$DERIVED" "$OUT/$APP_NAME" "$OUT/$ZIP_NAME"
mkdir -p "$OUT"

echo "==> xcodebuild ($CONFIG)…"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  -destination "platform=macOS" \
  CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}" \
  CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}" \
  build

BUILT="$DERIVED/Build/Products/$CONFIG/$APP_NAME"
if [[ ! -d "$BUILT" ]]; then
  echo "未找到: $BUILT" >&2
  exit 1
fi

cp -R "$BUILT" "$OUT/"
(
  cd "$OUT"
  ditto -c -k --sequesterRsrc --keepParent "$APP_NAME" "$ZIP_NAME"
)

echo "==> 完成: $OUT/$ZIP_NAME"
echo "    可将该 zip 作为 GitHub Release 的附件上传。"

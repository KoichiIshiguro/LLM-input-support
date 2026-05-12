#!/bin/bash
set -e

APP_NAME="LLMime"
LOCAL_APP="/tmp/$APP_NAME.app"

swift build

# バイナリのパスを検索
BINARY=$(find .build -name "$APP_NAME" -type f ! -path "*.dSYM*" | head -1)
if [ -z "$BINARY" ]; then
    echo "Error: Binary not found"
    exit 1
fi

# .app バンドルを /tmp に構築
rm -rf "$LOCAL_APP"
mkdir -p "$LOCAL_APP/Contents/MacOS"
mkdir -p "$LOCAL_APP/Contents/Resources"

COPYFILE_DISABLE=1 cp "$BINARY" "$LOCAL_APP/Contents/MacOS/$APP_NAME"
cp "LLMime/Info.plist" "$LOCAL_APP/Contents/Info.plist"

# リソースバンドルがあればコピー
BUNDLE=$(find .build -name "LLMime_LLMime.bundle" -type d | head -1)
if [ -n "$BUNDLE" ]; then
    COPYFILE_DISABLE=1 cp -R "$BUNDLE/"* "$LOCAL_APP/Contents/Resources/" 2>/dev/null || true
fi

find "$LOCAL_APP" -name '._*' -delete

# 自己署名証明書で署名（リビルドしても権限が維持される）
IDENTITY=$(security find-identity -v -p codesigning | grep "LLMime Dev" | head -1 | awk -F'"' '{print $2}')
if [ -n "$IDENTITY" ]; then
    codesign --force --deep --sign "$IDENTITY" "$LOCAL_APP"
else
    echo "Warning: LLMime Dev certificate not found, using ad-hoc"
    codesign --force --deep --sign - "$LOCAL_APP"
fi

echo ""
echo "Built & signed: $LOCAL_APP"
echo "Run:  $LOCAL_APP/Contents/MacOS/$APP_NAME"
echo "Or:   open $LOCAL_APP"

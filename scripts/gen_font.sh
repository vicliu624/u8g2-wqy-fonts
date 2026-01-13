#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor"
GENERATED="$ROOT/generated"
BDF_TMP="$GENERATED/tmp.bdf"
BDFCONV_DIR="$VENDOR/u8g2/tools/font/bdfconv"
OTF2BDF_DIR="$VENDOR/u8g2/tools/font/otf2bdf"

U8G2_TARBALL_URL="https://github.com/olikraus/u8g2/archive/refs/heads/master.tar.gz"
WQY_TTF_URL="https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf"
PINYIN_DATA="$ROOT/data/PinyinData.h"

FONT_NAME="u8g2_font_wqy18_t_gb2312"
FONT_SIZE=18
MAP_FILE="$ROOT/data/gb2312_level1.map"
TTF_PATH="$VENDOR/NotoSansSC-Regular.otf"
OUTPUT_C="$GENERATED/${FONT_NAME}.c"
SRC_DIR="$ROOT/src"
INC_DIR="$ROOT/include"

mkdir -p "$VENDOR" "$GENERATED"

echo "[1/3] Download u8g2 sources..."
if [ ! -d "$VENDOR/u8g2" ]; then
    curl -L --retry 5 --retry-delay 2 --fail "$U8G2_TARBALL_URL" -o "$VENDOR/u8g2.tar.gz"
    tar -xf "$VENDOR/u8g2.tar.gz" -C "$VENDOR"
    mv "$VENDOR"/u8g2-* "$VENDOR/u8g2"
fi

echo "[2/3] Download font (NotoSansSC-Regular)..."
if [ ! -f "$TTF_PATH" ]; then
    curl -L --retry 5 --retry-delay 2 --fail "$WQY_TTF_URL" -o "$TTF_PATH"
fi

echo "[3/3] Build bdfconv and generate ${FONT_NAME}.c ..."
if [ ! -x "$OTF2BDF_DIR/otf2bdf" ]; then
    if command -v freetype-config >/dev/null 2>&1; then
        chmod +x "$OTF2BDF_DIR/configure"
        (cd "$OTF2BDF_DIR" && ./configure && make) >/dev/null
    else
        # fallback: use pkg-config directly
        CFLAGS="$(pkg-config --cflags freetype2)"
        LIBS="$(pkg-config --libs freetype2)"
        cc $CFLAGS -o "$OTF2BDF_DIR/otf2bdf" "$OTF2BDF_DIR/otf2bdf.c" "$OTF2BDF_DIR/remap.c" $LIBS
    fi
fi
if [ ! -x "$OTF2BDF_DIR/otf2bdf" ]; then
    echo "otf2bdf build failed; ensure freetype dev and pkg-config are installed." >&2
    exit 1
fi

make -C "$BDFCONV_DIR" >/dev/null

set +e
"$OTF2BDF_DIR/otf2bdf" \
    -p "$FONT_SIZE" \
    -r 100 \
    -o "$BDF_TMP" \
    "$TTF_PATH"
OTF2BDF_RC=$?
set -e
if [ ! -s "$BDF_TMP" ]; then
    echo "otf2bdf failed to produce BDF (rc=$OTF2BDF_RC)" >&2
    exit 1
fi

"$BDFCONV_DIR/bdfconv" \
    -f 1 \
    -M "$MAP_FILE" \
    -r "$FONT_SIZE" \
    -n "$FONT_NAME" \
    -o "$OUTPUT_C" \
    "$BDF_TMP"

echo "Font generated: $OUTPUT_C"
ls -lh "$OUTPUT_C"

# 同步到 src/ 与 include/
mkdir -p "$SRC_DIR" "$INC_DIR"
cp "$OUTPUT_C" "$SRC_DIR/"
cat > "$INC_DIR/${FONT_NAME}.h" <<EOF
#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
extern const uint8_t ${FONT_NAME}[];
#ifdef __cplusplus
}
#endif
EOF
echo "Synced to $SRC_DIR/ and $INC_DIR/${FONT_NAME}.h"

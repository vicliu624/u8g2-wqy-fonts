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

FONT_NAME="u8g2_font_wqy19_t_gb2312"
FONT_SIZE=19
MAP_FILE="$GENERATED/pinyin_ascii.map"
TTF_PATH="$VENDOR/NotoSansSC-Regular.otf"
OUTPUT_C="$GENERATED/${FONT_NAME}.c"

mkdir -p "$VENDOR" "$GENERATED"

echo "[1/3] 下载 u8g2 源码..."
if [ ! -d "$VENDOR/u8g2" ]; then
    curl -L --retry 5 --retry-delay 2 --fail "$U8G2_TARBALL_URL" -o "$VENDOR/u8g2.tar.gz"
    tar -xf "$VENDOR/u8g2.tar.gz" -C "$VENDOR"
    mv "$VENDOR"/u8g2-* "$VENDOR/u8g2"
fi

echo "[2/3] 下载中文字体 (NotoSansSC-Regular)..."
if [ ! -f "$TTF_PATH" ]; then
    curl -L --retry 5 --retry-delay 2 --fail "$WQY_TTF_URL" -o "$TTF_PATH"
fi

echo "[3/3] 编译 bdfconv 并生成 ${FONT_NAME}.c ..."
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
    echo "otf2bdf 构建失败，请确认系统已安装 freetype 开发工具链（libfreetype-dev, pkg-config 等）。" >&2
    exit 1
fi

make -C "$BDFCONV_DIR" >/dev/null

# 生成 ASCII + PinyinData.h 覆盖的汉字集合映射表（十进制码点）
MAP_FILE="$MAP_FILE" PINYIN_DATA="$PINYIN_DATA" python3 - <<'PY'
import os, re
from pathlib import Path

chars = set(range(32, 128))  # ASCII printable

pinyin_path = Path(os.environ["PINYIN_DATA"])
txt = pinyin_path.read_text(encoding="utf-8")
start = txt.find('R"PINYIN_DICT(')
end = txt.find(')PINYIN_DICT"', start)
if start == -1 or end == -1:
    raise SystemExit("PinyinData.h 未找到 PINYIN_DICT 段")
body = txt[start + len('R"PINYIN_DICT(') : end]
for ch in body:
    if ch.isascii() or ch.isspace():
        continue
    chars.add(ord(ch))

path = Path(os.environ["MAP_FILE"])
path.write_text(",".join(str(c) for c in sorted(chars)), encoding="utf-8")
print(f"map written to {path}, count={len(chars)}")
PY

set +e
"$OTF2BDF_DIR/otf2bdf" \
    -p "$FONT_SIZE" \
    -r 100 \
    -o "$BDF_TMP" \
    "$TTF_PATH"
OTF2BDF_RC=$?
set -e
if [ ! -s "$BDF_TMP" ]; then
    echo "otf2bdf 生成 BDF 失败 (rc=$OTF2BDF_RC)" >&2
    exit 1
fi

"$BDFCONV_DIR/bdfconv" \
    -f 1 \
    -M "$MAP_FILE" \
    -r "$FONT_SIZE" \
    -n "$FONT_NAME" \
    -o "$OUTPUT_C" \
    "$BDF_TMP"

echo "生成完成: $OUTPUT_C"
ls -lh "$OUTPUT_C"

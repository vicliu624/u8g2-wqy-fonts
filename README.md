## u8g2-wqy-fonts

Lightweight U8g2 font pack for Meshtastic T-Deck/T-Deck-Pro.
- 19px font matching `FONT_HEIGHT_SMALL` (19px) visual height.
- Keep the repo lean: generation script, font source (TTF), generated C file only.
- Intended to be pulled via `lib_deps` in `platformio.ini` for T-Deck/T-Deck-Pro only.

### Layout
- `scripts/gen_font.sh`: one-click generation (download deps, build otf2bdf/bdfconv, produce C font and sync to src/include).
- `vendor/`: cached deps (u8g2 sources, NotoSansSC subset OTF, etc.).
- `generated/`: intermediate outputs (BDF, map files, temporary C).
- `src/`: final C font for PlatformIO builds.
- `include/`: header for inclusion.
- `data/`: `PinyinData.h` copied from firmware, used to build the Chinese whitelist.

### Generation steps
```bash
cd /home/vicliu/Projects/meshtastic/u8g2-wqy-fonts
./scripts/gen_font.sh
```
The script will:
1) Download u8g2 sources and build `otf2bdf` / `bdfconv`.
2) Download `NotoSansSC-Regular.otf` (Google open-source Simplified Chinese font subset).
3) Extract all characters appearing in `data/PinyinData.h`, generate `generated/pinyin_ascii.map` (~6.8k chars).
4) Generate an 18px whitelist font, syncing to `src/u8g2_font_wqy18_t_gb2312.c` and `include/u8g2_font_wqy18_t_gb2312.h` (current size ~1.5 MB).

Note: `data/PinyinData.h` is copied from firmware; if the input table changes, sync it here and rerun the script.

#### Requirements
- gcc, make
- FreeType dev (e.g., `sudo apt-get install libfreetype6-dev pkg-config` on Debian/Ubuntu)
- curl, tar

### PlatformIO usage (example)
In firmware `platformio.ini` (T-Deck/T-Deck-Pro only) add:
```ini
lib_deps =
  https://github.com/vicliu624/u8g2-wqy-fonts.git#v0.1.0
build_flags =
  -Iinclude
```
In code:
```cpp
#include "u8g2_font_wqy19_t_gb2312.h"
// ...
u8g2->setFont(u8g2_font_wqy19_t_gb2312);
u8g2->setFontPosTop();
const int baseline = y + u8g2->getAscent();
```
Compute line height/baseline via `getMaxCharHeight()` / `getAscent()`; avoid hard-coding offsets.

### Regeneration
- To change size or charset, tweak parameters in `scripts/gen_font.sh` (`FONT_NAME`, `FONT_SIZE`, whitelist source, etc.) and rerun to resync src/include.

### License
- Font: Noto Sans CJK SC under SIL Open Font License 1.1.
- Scripts/code: MIT (see `library.json` / `LICENSE`).

## u8g2-wqy-fonts

面向 Meshtastic T-Deck/T-Deck-Pro 的轻量级 U8g2 字体库。目标：
- 生成 19px、高度接近 `FONT_HEIGHT_SMALL`（19px）的 GB2312 字体，保证与现有 UI 字体一致。
- 保持仓库精简，仅包含生成脚本、字体源（TTF）、生成的 C 文件。
- 可作为独立 Git 仓库，通过 `platformio.ini` 的 `lib_deps` 仅在 T-Deck/T-Deck-Pro 环境引入。

### 目录
- `scripts/gen_font.sh`：一键生成字体（下载依赖、编译 bdfconv、生成 C 字体文件）。
- `vendor/`：存放下载的依赖（u8g2 源码、微米黑字体 TTF）。
- `generated/`：输出的 U8g2 字体文件（`u8g2_font_wqy19_t_gb2312.c`）。

### 生成步骤
```bash
cd /home/vicliu/Projects/meshtastic/u8g2-wqy-fonts
./scripts/gen_font.sh
```
脚本会：
1) 下载 u8g2 源码并编译 `bdfconv`。
2) 下载 `NotoSansSC-Regular.otf`（Google 开源简体中文字体）。
3) 生成 19px 的精简字体：只包含 ASCII + `PinyinData.h` 中出现的全部汉字（目前约 6.8k 个，映射表 `generated/pinyin_ascii.map`），输出 `generated/u8g2_font_wqy19_t_gb2312.c`（当前约 1.5 MB）。

附：`data/PinyinData.h` 复制自 firmware，用来生成白名单；若后续 firmware 侧更新输入表，请同步到此项目再运行脚本。

#### 依赖
- gcc、make
- `freetype-config` / FreeType 开发包（Debian/Ubuntu: `sudo apt-get install libfreetype6-dev pkg-config`）
- curl、tar

### 在 firmware 中的使用建议
- 在 firmware 的 `platformio.ini` 里为 `t-deck` / `t-deck-pro` 增加本库的 git 地址（`lib_deps`）。
- 渲染代码（MessageRenderer/CannedMessage 等）使用：
  - `setFont(u8g2_font_wqy19_t_gb2312);`
  - `setFontPosTop();`
  - 行高/基线使用 `getMaxCharHeight()` / `getAscent()` 动态计算，避免硬编码。

### 重新生成
- 若需其他字号或字符集，修改 `scripts/gen_font.sh` 中的 `FONT_NAME`、`FONT_SIZE`、`ENCODING` 参数，再运行脚本。

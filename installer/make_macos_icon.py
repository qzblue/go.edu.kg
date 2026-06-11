# 从品牌 logo 生成 macOS 应用图标 (AppIcon.appiconset)。
# 按 macOS 规范留约 18% 透明边距，让 Dock 里观感正常。
# 用法：在 source/installer/ 下 `python make_macos_icon.py`
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "assets", "images", "icon_android.png")  # 1024 满版 logo
DST = os.path.join(HERE, "..", "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")

logo = Image.open(SRC).convert("RGBA")
CONTENT = 0.82  # 内容占比，四周留透明边距（macOS 风格）

# Contents.json 需要这些像素尺寸的 png
SIZES = [16, 32, 64, 128, 256, 512, 1024]

for n in SIZES:
    canvas = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    c = max(1, round(n * CONTENT))
    body = logo.resize((c, c), Image.LANCZOS)
    off = (n - c) // 2
    canvas.paste(body, (off, off), body)
    out = os.path.join(DST, f"app_icon_{n}.png")
    canvas.save(out, format="PNG")
    print("wrote", out, canvas.size)
print("done")

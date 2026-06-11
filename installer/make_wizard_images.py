# 从应用 logo 生成 Inno Setup 向导横幅图（品牌深蓝底 + 居中 logo）。
# 用法：在 source/installer/ 下运行 `python make_wizard_images.py`
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC_LOGO = os.path.join(HERE, "..", "assets", "images", "icon.png")
OUT = HERE
NAVY = (1, 17, 46)        # #01112E 品牌底色
NAVY2 = (10, 40, 92)      # 顶部稍亮，做竖向渐变

logo = Image.open(SRC_LOGO).convert("RGBA")

def vgrad(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        row = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = row
    return img

def paste_logo(bg, size, cx, cy):
    lg = logo.resize((size, size), Image.LANCZOS)
    bg.paste(lg, (cx - size // 2, cy - size // 2), lg)

def make(name, w, h, logo_size, cy):
    bg = vgrad(w, h, NAVY2, NAVY)
    paste_logo(bg, logo_size, w // 2, cy)
    bg.save(os.path.join(OUT, name), format="BMP")
    print("wrote", name, bg.size)

make("wizard_large.bmp", 164, 314, 110, 110)
make("wizard_large@2x.bmp", 328, 628, 220, 220)
make("wizard_small.bmp", 55, 58, 46, 29)
make("wizard_small@2x.bmp", 110, 116, 92, 58)
print("done")

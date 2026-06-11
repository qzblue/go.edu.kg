# 从 go.edu.kg 圆形 logo 生成系统托盘图标 status_1/2/3.{ico,png}。
# status_1 = 未连接(灰暗)，status_2/3 = 已连接/TUN(彩色)。
# 用法：在 source/installer/ 下运行 `python make_tray_icons.py`
import urllib.request, io, os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
URL = "https://go.edu.kg/images/uim-logo-round_96x96.png"
DST = os.path.join(HERE, "..", "assets", "images", "icon")

data = urllib.request.urlopen(URL, timeout=30).read()
src = Image.open(io.BytesIO(data)).convert("RGBA")
print("source", src.size, src.mode, len(data), "bytes")

base = src.resize((256, 256), Image.LANCZOS)

def desaturate(img, factor=0.55):
    """灰度 + 降透明度 → '未连接' 观感。"""
    gray = img.convert("RGB").convert("L").convert("RGB")
    r, g, b = gray.split()
    a = img.split()[3].point(lambda v: int(v * factor))
    return Image.merge("RGBA", (r, g, b, a))

color = base
gray = desaturate(base)
ICO_SIZES = [(16, 16), (20, 20), (24, 24), (32, 32), (40, 40), (48, 48), (64, 64), (128, 128), (256, 256)]

def save(img, name):
    img.save(os.path.join(DST, name + ".ico"), format="ICO", sizes=ICO_SIZES)
    img.save(os.path.join(DST, name + ".png"), format="PNG")
    print("wrote", name + ".ico/.png")

save(gray, "status_1")
save(color, "status_2")
save(color, "status_3")
print("done")

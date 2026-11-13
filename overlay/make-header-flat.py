"""极简纯色风格的顶栏：纯色底 + 标题，不放插画。"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

dst = sys.argv[1] if len(sys.argv) > 1 else "assets/header-flat.png"
W, H = 1280, 168

bg = Image.new("RGB", (W, H), (14, 18, 30))
d = ImageDraw.Draw(bg)

# 底部一道极细的分隔线
d.rectangle([0, H - 2, W, H - 1], fill=(34, 41, 62))

try:
    f_title = ImageFont.truetype("C:/Windows/Fonts/msyhbd.ttc", 46)
    f_sub = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 24)
except Exception:
    f_title = ImageFont.load_default()
    f_sub = ImageFont.load_default()

d.text((40, 36), "快速问答", font=f_title, fill=(240, 244, 255))
d.text((42, 96), "截图 · 翻译 · 讲解 · 一键作答", font=f_sub, fill=(150, 162, 190))

# 左侧竖条强调色
d.rectangle([40, 150, 96, 152], fill=(91, 124, 255))

os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
bg.save(dst, "PNG", optimize=True)
print("saved", dst, bg.size)

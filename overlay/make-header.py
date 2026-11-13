"""生成快速问答/快速翻译小窗的顶部条：虚化鲸鱼娘 + 圆形头像 + 标题。

用法：python make-header.py <立绘webp> <输出png> [标题] [副标题]
输出 1280x168（= 640x84 @2x）
"""
import os
import sys
from PIL import Image, ImageFilter, ImageEnhance, ImageDraw, ImageFont

src, dst = sys.argv[1], sys.argv[2]
title = sys.argv[3] if len(sys.argv) > 3 else "快速问答"
subtitle = sys.argv[4] if len(sys.argv) > 4 else "鲸鱼娘在线 · 框一段就出答案"

W, H = 1280, 168

im = Image.open(src).convert("RGBA")
sw, sh = im.size

band_h = int(sh * 0.16)
band = im.crop((0, int(sh * 0.01), sw, int(sh * 0.01) + band_h))
scale = W / band.width
band = band.resize((W, int(band_h * scale)), Image.LANCZOS)
band = band.filter(ImageFilter.GaussianBlur(12))
band = ImageEnhance.Color(band).enhance(0.75)
band = ImageEnhance.Brightness(band).enhance(0.55)

bg = Image.new("RGBA", (W, H), (11, 15, 30, 255))
bg.alpha_composite(band.crop((0, 0, W, H)))

veil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
vd = ImageDraw.Draw(veil)
for x in range(W):
    a = int(150 * max(0.0, 1 - x / (W * 0.75)))
    vd.line([(x, 0), (x, H)], fill=(8, 11, 24, a))
bg.alpha_composite(veil)

face_w = int(sw * 0.40)
cx = int(sw * 0.50)
cy = int(sh * 0.115)
left = max(0, cx - face_w // 2)
top = max(0, cy - face_w // 2)
face = im.crop((left, top, left + face_w, top + face_w))
avatar_size = 116
face = face.resize((avatar_size, avatar_size), Image.LANCZOS)

mask = Image.new("L", (avatar_size * 4, avatar_size * 4), 0)
ImageDraw.Draw(mask).ellipse((0, 0, avatar_size * 4 - 1, avatar_size * 4 - 1), fill=255)
mask = mask.resize((avatar_size, avatar_size), Image.LANCZOS)

ring = Image.new("RGBA", (avatar_size + 8, avatar_size + 8), (0, 0, 0, 0))
ImageDraw.Draw(ring).ellipse((0, 0, avatar_size + 7, avatar_size + 7), fill=(120, 148, 255, 210))
ring.paste(face, (4, 4), mask)

ax, ay = 44, (H - (avatar_size + 8)) // 2
bg.alpha_composite(ring, (ax, ay))

draw = ImageDraw.Draw(bg)
try:
    f_title = ImageFont.truetype("C:/Windows/Fonts/msyhbd.ttc", 46)
    f_sub = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 24)
except Exception:
    f_title = ImageFont.load_default()
    f_sub = ImageFont.load_default()

tx = ax + avatar_size + 34
draw.text((tx, 36), title, font=f_title, fill=(240, 244, 255, 255))
draw.text((tx + 2, 96), subtitle, font=f_sub, fill=(168, 181, 214, 255))

out = bg.convert("RGB")
os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
out.save(dst, "PNG", optimize=True)
print("saved", dst, out.size, os.path.getsize(dst) // 1024, "KB")

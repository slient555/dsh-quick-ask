"""生成快速问答小窗的底图（1280x1520 = 640x760 @2x）。

上半：放大后的虚化鲸鱼娘 + 标题（标题画进图里，避免透明标签发虚）
下半：深色渐变，交给面板盖住

用法：python make-bg.py <鲸鱼娘立绘webp> <输出png>
"""
import os
import sys
from PIL import Image, ImageFilter, ImageEnhance, ImageDraw, ImageFont

src, dst = sys.argv[1], sys.argv[2]
W, H = 1280, 1520
HERO = 440
ZOOM = 1.15
SHIFT = 0.06


def hgrad(w, h, peak, start=0.0, end=1.0):
    strip = Image.new("L", (w, 1), 0)
    px = strip.load()
    for x in range(w):
        t = x / max(1, w - 1)
        px[x, 0] = int(peak * max(0.0, min(1.0, (end - t) / max(1e-6, end - start))))
    return strip.resize((w, h))


# ---------- 1. 深海军蓝底 ----------
g = Image.linear_gradient("L").resize((W, H))
top = Image.new("RGB", (W, H), (30, 39, 74))
bot = Image.new("RGB", (W, H), (7, 9, 20))
base = Image.composite(bot, top, g)

# ---------- 2. 角色 ----------
im = Image.open(src).convert("RGBA")
sw, sh = im.size
head = im.crop((0, 0, sw, int(sh * 0.42)))
scale = (W * ZOOM) / sw
head = head.resize((int(head.width * scale), int(head.height * scale)), Image.LANCZOS)
head = head.filter(ImageFilter.GaussianBlur(7))
head = ImageEnhance.Color(head).enhance(0.9)
head = ImageEnhance.Brightness(head).enhance(0.92)

fh, fw = head.size
fade = Image.new("L", head.size, 255)
d = ImageDraw.Draw(fade)
start = int(fh * 0.45)
for y in range(start, fh):
    t = (y - start) / max(1, fh - start)
    d.line([(0, y), (fw, y)], fill=int(255 * (1 - t) ** 1.6))
fade = fade.filter(ImageFilter.GaussianBlur(24))
head.putalpha(Image.composite(head.getchannel("A"), Image.new("L", head.size, 0), fade))

off = int(head.width * SHIFT)
crop = head.crop((off, 0, off + W, min(H, head.height)))
canvas = base.convert("RGBA")
canvas.alpha_composite(crop, (0, 0))

# ---------- 3. 左侧压暗 ----------
shade = hgrad(W, HERO + 300, 170, 0.0, 0.70).filter(ImageFilter.GaussianBlur(56))
veil = Image.new("L", (W, HERO + 300), 0)
vd = ImageDraw.Draw(veil)
for y in range(HERO + 300):
    k = 1.0 if y < HERO - 20 else max(0.0, 1 - (y - (HERO - 20)) / 260.0)
    vd.line([(0, y), (W, y)], fill=int(255 * k))
lay = Image.composite(veil, Image.new("L", veil.size, 0), shade)
canvas.alpha_composite(Image.merge("RGBA", (
    Image.new("RGB", lay.size, (6, 9, 22)).split()[0],
    Image.new("RGB", lay.size, (6, 9, 22)).split()[1],
    Image.new("RGB", lay.size, (6, 9, 22)).split()[2],
    lay,
)), (0, 0))

# ---------- 4. 标题 ----------
draw = ImageDraw.Draw(canvas)
try:
    f_title = ImageFont.truetype("C:/Windows/Fonts/msyhbd.ttc", 92)
    f_sub = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 36)
except Exception:
    f_title = ImageFont.load_default()
    f_sub = ImageFont.load_default()

draw.text((64, 60), "快速问答", font=f_title, fill=(240, 244, 255, 255))
draw.text((66, 196), "鲸鱼娘在线  ·  框一段就出答案", font=f_sub, fill=(182, 194, 224, 255))
draw.rectangle([64, 172, 196, 176], fill=(104, 132, 255, 255))

out = canvas.convert("RGB")
os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
out.save(dst, "PNG", optimize=True)
print("saved", dst, out.size, os.path.getsize(dst) // 1024, "KB")

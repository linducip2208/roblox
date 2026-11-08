from PIL import Image, ImageDraw, ImageFont
from repo import BASE
import pathlib

out = pathlib.Path(str(BASE) + r"\assets\out")

def font(sz):
    for p in (r"C:\Windows\Fonts\impact.ttf", r"C:\Windows\Fonts\arialbd.ttf", r"C:\Windows\Fonts\arial.ttf"):
        try:
            return ImageFont.truetype(p, sz)
        except Exception:
            continue
    return ImageFont.load_default()

def load(name, size):
    p = out / (name + ".png")
    img = Image.open(p).convert("RGB")
    # crop frame + label: buang 45px tiap sisi
    w, h = img.size
    img = img.crop((45, 45, w - 45, h - 100))
    return img.resize((size, size))

def text_stroke(d, xy, s, fnt, fill, stroke=(0, 0, 0)):
    x, y = xy
    for ox in (-4, 0, 4):
        for oy in (-4, 0, 4):
            d.text((x + ox, y + oy), s, font=fnt, fill=stroke)
    d.text((x, y), s, font=fnt, fill=fill)

def arrow(d, x1, y1, x2, y2, w=25, color=(255, 0, 0)):
    d.line([x1, y1, x2, y2], fill=color, width=w)
    d.polygon([(x2-60, y2-40), (x2-60, y2+40), (x2+20, y2)], fill=color)

def thumb_a():
    bg = Image.new("RGB", (1920, 1080), (120, 200, 255))
    d = ImageDraw.Draw(bg)
    d.rectangle([0, 700, 1920, 1080], fill=(100, 170, 90))
    hero = load("semangka_mewing", 500)
    bg.paste(hero, (710, 300))
    side1 = load("cabai_noob", 300)
    bg.paste(side1, (250, 550))
    side2 = load("pisang_sultan", 300)
    bg.paste(side2, (1370, 550))
    arrow(d, 300, 200, 800, 450)
    text_stroke(d, (560, 60), "CURI!!!", font(160), (255, 220, 0))
    d.text((500, 900), "STEAL A KEBUN [BETA]", fill=(0, 0, 0))
    bg.save(out / "thumb-1.png")

def thumb_b():
    bg = Image.new("RGB", (1920, 1080), (60, 60, 120))
    d = ImageDraw.Draw(bg)
    for i in range(0, 1920, 40):
        d.line([i, 0, i - 200, 1080], fill=(90, 90, 170), width=10)
    a = load("payung_raksasa", 550)
    bg.paste(a, (200, 300))
    b = load("kopi_hujan", 550)
    bg.paste(b, (1170, 300))
    arrow(d, 900, 540, 1100, 540, w=35)
    text_stroke(d, (420, 60), "HUJAN KOPI x2", font(120), (255, 255, 255))
    bg.save(out / "thumb-2.png")

def thumb_c():
    bg = Image.new("RGB", (1920, 1080), (30, 30, 30))
    d = ImageDraw.Draw(bg)
    d.ellipse([560, 40, 1360, 840], outline=(0, 255, 255), width=15)
    hero = load("kopi_gacor-rainbow", 700)
    bg.paste(hero, (610, 190))
    text_stroke(d, (480, 900), "SECRET RAINBOW!", font(110), (255, 215, 0))
    bg.save(out / "thumb-3.png")

def icon():
    bg = Image.new("RGB", (512, 512), (255, 210, 60))
    d = ImageDraw.Draw(bg)
    hero = load("kopi_gacor", 300)
    bg.paste(hero, (106, 106))
    s1 = load("cabai_noob", 130)
    bg.paste(s1, (20, 340))
    s2 = load("stroberi_tung", 130)
    bg.paste(s2, (362, 340))
    bg.save(out / "icon-512.png")

thumb_a(); thumb_b(); thumb_c(); icon()
print("thumbs + icon done")

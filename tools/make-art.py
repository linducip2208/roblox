from PIL import Image, ImageDraw
import pathlib, math

out = pathlib.Path(r"D:\project laravel\roblox\assets\out")
out.mkdir(parents=True, exist_ok=True)

# body color, shape, accessory per item — tiap item beda
ITEMS = {
 "cabai_noob":      ((220,40,40), "chili", None),
 "wortel_goyang":   ((250,140,30), "tall", "shades"),
 "tomat_gendut":    ((235,60,60), "round", None),
 "jagung_rave":     ((250,210,60), "tall", "headphones"),
 "terong_disco":    ((130,60,200), "oval", "sparkle"),
 "semangka_mewing": ((60,180,80), "round", "chad"),
 "pisang_sultan":   ((255,225,80), "banana", "crown"),
 "durian_megar":    ((140,180,60), "spiky", None),
 "anggur_roblox":   ((120,60,200), "grapes", "matrix"),
 "mangga_ohio":     ((255,160,40), "oval", "weird"),
 "apel_brainrot":   ((220,30,30), "round", "teeth"),
 "nanas_jet":       ((240,200,50), "oval", "jets"),
 "kelapa_godzilla": ((120,90,60), "round", "spikes"),
 "melon_skibidi":   ((100,200,120), "round", "toilet"),
 "stroberi_tung":   ((240,60,90), "heart", "stick"),
 "leci_tralala":    ((255,200,200), "round", "shoes"),
 "kiwi_bombardilo": ((140,170,70), "oval", "wings"),
 "sirsak_titan":    ((150,200,150), "spiky", "armor"),
 "sawit_garut":     ((220,170,40), "oval", "halo"),
 "kopi_gacor":      ((120,70,40), "cup", "wings"),
 "kopi_hujan":      ((150,100,70), "cup", "umbrella"),
 "payung_raksasa":  ((220,60,60), "umbrella", None),
}

RARITY_BG = {
 "Common": (200,235,200), "Uncommon": (180,220,255), "Rare": (210,180,255),
 "Epic": (255,180,220), "Legendary": (255,230,150), "Mythic": (255,150,150),
 "Secret": (150,255,255), "Event": (230,200,170),
}
RARITY_OF = {"cabai_noob":"Common","wortel_goyang":"Common","tomat_gendut":"Common",
 "jagung_rave":"Uncommon","terong_disco":"Uncommon","semangka_mewing":"Uncommon",
 "pisang_sultan":"Rare","durian_megar":"Rare","anggur_roblox":"Rare",
 "mangga_ohio":"Epic","apel_brainrot":"Epic","nanas_jet":"Epic",
 "kelapa_godzilla":"Legendary","melon_skibidi":"Legendary","stroberi_tung":"Legendary",
 "leci_tralala":"Mythic","kiwi_bombardilo":"Mythic","sirsak_titan":"Mythic",
 "sawit_garut":"Secret","kopi_gacor":"Secret","kopi_hujan":"Event","payung_raksasa":"Event"}

def draw_face(d, cx, cy, s, mood="happy", spread=0.28):
    e = s*0.12
    # mata
    d.ellipse([cx-s*spread-e, cy-s*0.1-e, cx-s*spread+e, cy-s*0.1+e], fill=(20,20,20))
    d.ellipse([cx+s*spread-e, cy-s*0.1-e, cx+s*spread+e, cy-s*0.1+e], fill=(20,20,20))
    d.ellipse([cx-s*spread-e//2, cy-s*0.1-e//2, cx-s*spread+e//3, cy-s*0.1+e//3], fill=(255,255,255))
    d.ellipse([cx+s*spread-e//2, cy-s*0.1-e//2, cx+s*spread+e//3, cy-s*0.1+e//3], fill=(255,255,255))
    # mulut
    if mood == "sad":
        d.arc([cx-s*0.15, cy+s*0.15, cx+s*0.15, cy+s*0.4], 200, 340, fill=(20,20,20), width=4)
    else:
        d.arc([cx-s*0.18, cy+s*0.05, cx+s*0.18, cy+s*0.35], 20, 160, fill=(20,20,20), width=5)

def draw_body(d, shape, cx, cy, s, color):
    if shape == "round":
        d.ellipse([cx-s//2, cy-s//2, cx+s//2, cy+s//2], fill=color, outline=(0,0,0), width=6)
    elif shape == "oval":
        d.ellipse([cx-s//2, cy-s*0.65, cx+s//2, cy+s*0.65], fill=color, outline=(0,0,0), width=6)
    elif shape == "tall":
        d.rounded_rectangle([cx-s*0.35, cy-s*0.7, cx+s*0.35, cy+s*0.7], radius=30, fill=color, outline=(0,0,0), width=6)
    elif shape == "chili":
        d.rounded_rectangle([cx-s*0.32, cy-s*0.5, cx+s*0.32, cy+s*0.45], radius=40, fill=color, outline=(0,0,0), width=6)
        d.polygon([(cx-s*0.32, cy+s*0.2), (cx+s*0.32, cy+s*0.2), (cx, cy+s*0.62)], fill=color, outline=(0,0,0))
        d.rectangle([cx-10, cy-s*0.72, cx+10, cy-s*0.5], fill=(40,140,40))
    elif shape == "banana":
        d.arc([cx-s*0.5, cy-s*0.4, cx+s*0.5, cy+s*0.5], 200, 340, fill=color, width=s//3)
    elif shape == "heart":
        d.ellipse([cx-s*0.45, cy-s*0.4, cx, cy+s*0.1], fill=color, outline=(0,0,0), width=5)
        d.ellipse([cx, cy-s*0.4, cx+s*0.45, cy+s*0.1], fill=color, outline=(0,0,0), width=5)
        d.polygon([(cx-s*0.42, cy), (cx+s*0.42, cy), (cx, cy+s*0.55)], fill=color, outline=(0,0,0))
    elif shape == "spiky":
        for a in range(0, 360, 30):
            x = cx + math.cos(math.radians(a))*s*0.55
            y = cy + math.sin(math.radians(a))*s*0.55
            d.polygon([(cx, cy), (x-12, y-12), (x+12, y+12)], fill=(60,120,40))
        d.ellipse([cx-s*0.4, cy-s*0.4, cx+s*0.4, cy+s*0.4], fill=color, outline=(0,0,0), width=6)
    elif shape == "grapes":
        for (ox, oy) in [(-30,-30),(30,-30),(-30,20),(30,20),(0,60)]:
            d.ellipse([cx+ox-28, cy+oy-28, cx+ox+28, cy+oy+28], fill=color, outline=(0,0,0), width=4)
    elif shape == "cup":
        d.polygon([(cx-s*0.35, cy-s*0.4), (cx+s*0.35, cy-s*0.4), (cx+s*0.25, cy+s*0.5), (cx-s*0.25, cy+s*0.5)], fill=color, outline=(0,0,0))
        d.ellipse([cx-s*0.35, cy-s*0.55, cx+s*0.35, cy-s*0.3], fill=(240,220,200), outline=(0,0,0), width=4)
    elif shape == "umbrella":
        d.pieslice([cx-s*0.6, cy-s*0.5, cx+s*0.6, cy+s*0.3], 180, 360, fill=color, outline=(0,0,0))
        d.line([cx, cy-s*0.1, cx, cy+s*0.6], fill=(80,50,30), width=10)
    # daun default
    if shape not in ("cup", "umbrella", "chili"):
        d.ellipse([cx+10, cy-s*0.62, cx+70, cy-s*0.35], fill=(50,160,50), outline=(0,0,0), width=3)

def draw_acc(d, acc, cx, cy, s):
    if acc == "crown":
        d.polygon([(cx-50, cy-s*0.62), (cx-50, cy-s*0.95), (cx-25, cy-s*0.72), (cx, cy-s*0.95), (cx+25, cy-s*0.72), (cx+50, cy-s*0.95), (cx+50, cy-s*0.62)], fill=(255,210,40), outline=(0,0,0))
    elif acc == "shades":
        d.rectangle([cx-s*0.4, cy-s*0.22, cx+s*0.4, cy+s*0.02], fill=(20,20,20))
    elif acc == "headphones":
        d.arc([cx-s*0.45, cy-s*0.5, cx+s*0.45, cy+s*0.2], 180, 360, fill=(40,40,40), width=12)
    elif acc == "halo":
        d.ellipse([cx-60, cy-s*0.85, cx+60, cy-s*0.6], outline=(255,215,0), width=8)
    elif acc == "wings":
        d.ellipse([cx-s*0.7, cy-20, cx-s*0.3, cy+40], fill=(255,255,255), outline=(0,0,0), width=3)
        d.ellipse([cx+s*0.3, cy-20, cx+s*0.7, cy+40], fill=(255,255,255), outline=(0,0,0), width=3)
    elif acc == "teeth":
        d.rectangle([cx-20, cy+s*0.15, cx+20, cy+s*0.3], fill=(255,255,255), outline=(0,0,0), width=3)
    elif acc == "spikes":
        for x in (-40, 0, 40):
            d.polygon([(cx+x-12, cy-s*0.5), (cx+x+12, cy-s*0.5), (cx+x, cy-s*0.8)], fill=(200,200,210), outline=(0,0,0))
    elif acc == "umbrella":
        d.pieslice([cx-70, cy-s*0.9, cx+70, cy-s*0.4], 180, 360, fill=(220,60,60), outline=(0,0,0))

def make_one(name, rarity):
    color, shape, acc = ITEMS[name]
    bg = RARITY_BG[rarity]
    img = Image.new("RGB", (512, 512), bg)
    d = ImageDraw.Draw(img)
    d.rectangle([8, 8, 504, 504], outline=(0, 0, 0), width=10)
    cx, cy, s = 256, 270, 260
    draw_body(d, shape, cx, cy, s, color)
    narrow = shape in ("chili", "banana", "tall", "cup")
    draw_face(d, cx, cy, s, mood="sad" if name == "cabai_noob" else "happy", spread=0.15 if narrow else 0.28)
    if acc: draw_acc(d, acc, cx, cy, s)
    d.text((20, 20), rarity.upper(), fill=(0, 0, 0))
    d.text((20, 470), name, fill=(0, 0, 0))
    return img

def apply_mut(img, mut):
    if mut == "gold":
        from PIL import ImageEnhance
        return ImageEnhance.Color(ImageEnhance.Brightness(img).enhance(1.15)).enhance(1.7)
    if mut == "dark":
        from PIL import ImageEnhance
        return ImageEnhance.Brightness(ImageEnhance.Contrast(img).enhance(1.3)).enhance(0.65)
    if mut == "rainbow":
        img = img.convert("RGB")
        bands = img.split()
        return Image.merge("RGB", (bands[2], bands[0], bands[1]))
    return img

n = 0
for name, rarity in RARITY_OF.items():
    base = make_one(name, rarity)
    base.save(out / (name + ".png"))
    n += 1
    for mut in ("gold", "dark", "rainbow"):
        apply_mut(base, mut).save(out / f"{name}-{mut}.png")
        n += 1
print("total digambar:", n)

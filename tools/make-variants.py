from PIL import Image, ImageEnhance
import pathlib
out = pathlib.Path(r"D:\project laravel\roblox\assets\out")
bases = [p for p in out.glob("*.png") if "-" not in p.name and "_" in p.name]
print("base:", len(bases))

def rainbow_fn(im):
    r, g, b = im.split()
    return Image.merge("RGB", (b, r, g))

made = 0
for src in bases:
    img = Image.open(src).convert("RGB")
    gold = ImageEnhance.Color(ImageEnhance.Brightness(img).enhance(1.2)).enhance(1.8)
    gold.save(src.parent / (src.stem + "-gold.png"))
    dark = ImageEnhance.Brightness(ImageEnhance.Contrast(img).enhance(1.4)).enhance(0.6)
    dark.save(src.parent / (src.stem + "-dark.png"))
    rainbow_fn(img).save(src.parent / (src.stem + "-rainbow.png"))
    made += 3
total = len(list(out.glob("*.png")))
print("varian baru:", made, "| total png:", total)

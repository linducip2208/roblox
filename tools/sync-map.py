import pathlib, re
mapf = pathlib.Path(r"D:\project laravel\roblox\src\Shared\AssetMap.luau")
t = mapf.read_text(encoding="utf-8")
have = set(re.findall(r'\["([^"]+)"\]', t))
out = pathlib.Path(r"D:\project laravel\roblox\assets\out")
files = sorted(p.stem for p in out.glob("*.png"))
# alias thumb/icon agar cocok dengan file out
aliases = {"thumb-1": "thumb_a", "thumb-2": "thumb_b", "thumb-3": "thumb_c", "icon-512": "icon"}
missing = [f for f in files if f not in have and f not in aliases]
print("tambah:", len(missing))
if missing:
    lines = "\n".join(f'\t["{m}"] = "",' for m in missing)
    t = t.replace('\t-- UI', lines + '\n\t-- UI')
    mapf.write_text(t, encoding="utf-8")
    print("AssetMap updated")

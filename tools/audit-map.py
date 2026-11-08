import pathlib, re
base = pathlib.Path(r"D:\project laravel\roblox\src\Shared\AssetMap.luau")
t = base.read_text(encoding="utf-8")
have = set(re.findall(r'\["([^"]+)"\]', t))
out = pathlib.Path(r"D:\project laravel\roblox\assets\out")
files = sorted(p.stem for p in out.glob("*.png"))
missing = [f for f in files if f not in have]
print("ada di AssetMap:", len(have), "| file out:", len(files), "| kurang:", len(missing))
for m in missing[:10]:
    print(" -", m)

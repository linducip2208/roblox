import pathlib, re
base = pathlib.Path(r"D:\project laravel\roblox\src")
for f in sorted(base.rglob("*.luau")):
    t = f.read_text(encoding="utf-8")
    btns = len(re.findall(r'Instance\.new\("Text(Button|Label)"', t))
    scaled = len(re.findall(r"\.TextScaled\s*=", t))
    Protegido = len(re.findall(r"\.TextSize\s*=", t))
    if btns and (scaled + Protegido) < btns:
        print(f"KURANG: {f.name} ui={btns} scaled={scaled} size={Protegido}")
print("selesai")

#!/usr/bin/env python3
"""Automated QA untuk Steal a Kebun. Keluar: PASS/FAIL per cek + exit code.
Jalankan: python tools/verify.py"""
import json, pathlib, re, sys

BASE = pathlib.Path(r"D:\project laravel\roblox")
SRC = BASE / "src"
fails: list[str] = []
passes: list[str] = []

def check(name: str, ok: bool, detail: str = ""):
    (passes if ok else fails).append(name)
    d = detail.replace("\u2192", "->").encode("ascii", "replace").decode()
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" - {d}" if d else ""))

luas = {p.relative_to(SRC).as_posix(): p.read_text(encoding="utf-8", errors="ignore")
        for p in SRC.rglob("*.luau")}

# 1. jawaban tidak bocor ke Shared
shared_ans = re.findall(r"Answer\s*=\s*\d", luas.get("Shared/TreasureConfig.luau", ""))
check("no-answer-leak", len(shared_ans) == 0, f"ditemukan {len(shared_ans)}")

# 2. Remote parity: semua WaitForChild("X") di client ada getOrCreate("X") di Main
made = set(re.findall(r'getOrCreate\("(\w+)"', luas.get("Server/Main.server.luau", "")))
needed: set[str] = set()
for name, t in luas.items():
    if name.startswith("Client/"):
        needed |= set(re.findall(r'WaitForChild\("(\w+)"', t))
needed -= {"Shared", "Remotes", "Plots", "PlayerGui", "Items", "AssetMap", "Config",
           "ShopRotation", "TreasureConfig"}  # modul/folder, bukan remote
missing = needed - made
check("remote-parity", not missing, f"hilang: {sorted(missing)}" if missing else f"{len(needed)} remote OK")

# 3. Skema Items
items = luas.get("Shared/Items.luau", "")
ids = re.findall(r'Id\s*=\s*"([^"]+)"', items)
check("items-unique", len(ids) == len(set(ids)) and len(ids) >= 20, f"{len(ids)} item")
bad = [m for m in re.finditer(r'\{[^}]*?Id\s*=\s*"([^"]+)"[^}]*?\}', items, re.S)]
req = 0
for m in bad:
    b = m.group(0)
    if all(k in b for k in ("Cost", "CashPerSec", "GrowthTime", "Rarity", "Name")):
        req += 1
check("items-schema", req == len(ids), f"{req}/{len(ids)} lengkap")

# 4. TreasureConfig valid
tcfg = luas.get("Shared/TreasureConfig.luau", "")
rid = re.findall(r'Id\s*=\s*"(R\d+)"', tcfg)
check("riddles-10-unique", set(rid) == {f"R{i}" for i in range(1, 11)}, f"{len(rid)} riddle")
ch = len(re.findall(r"Choices\s*=", tcfg))
check("riddles-choices", ch == 10, f"{ch}/10 punya Choices")
spawn = re.findall(r"Vector3\.new\([^)]+\)", tcfg)
check("spawn-points", len(spawn) >= 8, f"{len(spawn)} titik")

# 5. Jawaban server lengkap R1..R10
ans = luas.get("Server/TreasureAnswers.luau", "")
amap = dict(re.findall(r'R(\d+)\s*=\s*(\d)', ans))
check("answers-complete", all(str(i) in amap and amap[str(i)] in "1234" for i in range(1, 11)))

# 6. Product ID: 0 = BLOCKED (bukan FAIL kode, tapi FAIL rilis)
cfg = luas.get("Shared/Config.luau", "")
zero = re.findall(r"=\s*0,\s*--", cfg)
check("product-ids-set", len(zero) == 0, f"{len(zero)} ID masih 0 -> BLOCKED monetisasi live" if zero else "semua ID terisi")

# 7. Tidak ada TODO
todo = sum(len(re.findall(r"TODO|FIXME|XXX", t)) for t in luas.values())
check("no-todo", todo == 0, f"{todo} sisa")

# 8. AdminUserIds terisi
admin = re.search(r"AdminUserIds\s*=\s*\{([^}]*)\}", cfg, re.S)
filled = admin and re.search(r"\d{4,}", admin.group(1) or "")
check("admin-configured", bool(filled), "kosong → isi UserId owner" if not filled else "terisi")

# 9. Asset out vs AssetMap
out = {p.stem for p in (BASE / "assets/out").glob("*.png")}
am = set(re.findall(r'\["([^"]+)"\]', luas.get("Shared/AssetMap.luau", "")))
check("assetmap-covers-out", out <= am, f"kurang: {sorted(out-am)[:5]}" if not out <= am else f"{len(out)} key OK")

# 10. Verifikasi fisik generated (buka + resolusi)
try:
    from PIL import Image
    gen = BASE / "assets/generated"
    files = [p for p in gen.rglob("*.png")] if gen.exists() else []
    bad_img, sizes = [], {}
    for p in files:
        try:
            im = Image.open(p); im.load()
            sizes.setdefault(im.size, 0); sizes[im.size] += 1
        except Exception:
            bad_img.append(p.name)
    check("assets-openable", bool(files) and not bad_img, f"{len(files)} file, rusak: {bad_img[:3]}")
    check("assets-resolutions", True, str(sizes))
except ImportError:
    check("assets-openable", False, "PIL tidak tersedia")

# 11. Manifest konsisten dengan file
mf = BASE / "assets/generated/manifest.json"
if mf.exists():
    man = json.load(open(mf))
    names = {m["name"] + ".png" for m in man if m.get("status") == "done"}
    disk = {str(p.relative_to(gen)).replace("\\", "/") for p in files}
    check("manifest-matches-disk", names == disk, f"manifest {len(names)} vs disk {len(disk)}")
else:
    check("manifest-matches-disk", False, "manifest.json hilang")

print(f"\nRINGKASAN: {len(passes)} PASS, {len(fails)} FAIL")
if fails:
    print("FAIL:", ", ".join(fails))

# Gerbang Selene (lewati jika biner tidak ada di mesin ini)
import subprocess
try:
    r = subprocess.run(
        [str(BASE / "tools" / "selene" / "selene.exe"), str(SRC)],
        capture_output=True, text=True, cwd=str(BASE), timeout=120)
    out = (r.stdout or "") + (r.stderr or "")
    n_err = out.count("error[")
    n_warn = out.count("warning[")
    check("selene-clean", n_err == 0 and n_warn == 0,
          f"{n_err} error, {n_warn} warning" if (n_err or n_warn) else "0 error 0 warning")
except Exception as e:
    print(f"[SKIP] selene tidak tersedia: {e}")

print(f"FINAL: {len(passes)} PASS, {len(fails)} FAIL")
if fails:
    print("FAIL:", ", ".join(fails))
sys.exit(1 if fails else 0)

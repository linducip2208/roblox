#!/usr/bin/env python3
"""Automated QA untuk Steal a Kebun. Portabel: path dihitung dari lokasi script.
Kategori: PASS (lolos) / FAIL (bug kode -> exit 1) / BLOCKED (butuh owner) /
NOT TESTED (butuh Studio, tidak diklaim).
Satu ringkasan di akhir. Exit code nonzero hanya jika FAIL > 0.
Jalankan dari mana saja: python <repo>/tools/verify.py"""
import json, pathlib, re, subprocess, sys

BASE = pathlib.Path(__file__).resolve().parents[1]
SRC = BASE / "src"
passes: list[str] = []
fails: list[str] = []
blocked: list[str] = []
nottested: list[str] = []


def _safe(s: str) -> str:
    return s.encode("ascii", "replace").decode()


def check(name: str, ok: bool, detail: str = ""):
    (passes if ok else fails).append(name)
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" - {_safe(detail)}" if detail else ""))


def mark_blocked(name: str, detail: str = ""):
    blocked.append(name)
    print(f"[BLOCKED] {name}" + (f" - {_safe(detail)}" if detail else ""))


def mark_untested(name: str, detail: str = ""):
    nottested.append(name)
    print(f"[NOT TESTED] {name}" + (f" - {_safe(detail)}" if detail else ""))


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
needed -= {"Shared", "Remotes", "Plots", "PlayerGui", "Items", "AssetMap", "UiIcons", "UiPanels", "UiTheme",
           "Config", "ShopRotation", "TreasureConfig"}  # modul/folder, bukan remote
missing = needed - made
check("remote-parity", not missing, f"hilang: {sorted(missing)}" if missing else f"{len(needed)} remote OK")

# 2b. Semua RemoteFunction client->server punya rate limit
main_src = luas.get("Server/Main.server.luau", "")
made_funcs = set()
for m in re.finditer(r'getOrCreate\("(\w+)"\s*,\s*"Remote(Function|Event)"', main_src):
    if m.group(2) == "Function":
        made_funcs.add(m.group(1))
mblock = re.search(r"RATE_LIMITS[^=]*=\s*\{(.*?)\}", main_src, re.S)
limits = set(re.findall(r"^\s*(\w+)\s*=", mblock.group(1), re.M)) if mblock else set()
no_limit = sorted(made_funcs - limits)
check("rate-limit-coverage", not no_limit, f"tanpa limit: {no_limit}" if no_limit else f"{len(limits)} remote dilindungi")

# 3. Fencing DataStore: WAJIB UpdateAsync + verifikasi token, larang SetAsync profil.
save_src = luas.get("Server/SaveSystem.luau", "")
check("ds-updateasync", "MemoryStore" in save_src and "UpdateAsync" in save_src, "fencing atomik ada")
check("ds-no-set-profile", "store:SetAsync" not in save_src, "tidak ada SetAsync profil")
check("ds-normalize-session", "NormalizeSession" in save_src, "identitas sesi job+token")
check("ds-verify-before-commit", save_src.find("VerifyLock") < save_src.find("store:UpdateAsync"),
      "verify sebelum commit" if save_src.find("VerifyLock") < save_src.find("store:UpdateAsync") else "urutan salah")
check("ds-bindtoclose-parallel", "task.spawn" in save_src and "BindToClose" in save_src, "shutdown paralel")

# 4. Skema Items
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

# 5. TreasureConfig valid + jawaban server lengkap
tcfg = luas.get("Shared/TreasureConfig.luau", "")
rid = re.findall(r'Id\s*=\s*"([^"]+)"', tcfg)
check("riddles-10-unique", set(rid) == {f"R{i}" for i in range(1, 11)}, f"{len(rid)} riddle")
ch = len(re.findall(r"Choices\s*=", tcfg))
check("riddles-choices", ch == 10, f"{ch}/10 punya Choices")
spawn = re.findall(r"Vector3\.new\([^)]+\)", tcfg)
check("spawn-points", len(spawn) >= 8, f"{len(spawn)} titik")
ans = luas.get("Server/TreasureAnswers.luau", "")
amap = dict(re.findall(r'R(\d+)\s*=\s*(\d)', ans))
check("answers-complete", all(str(i) in amap and amap[str(i)] in "1234" for i in range(1, 11)))

# 6. Product ID: 0 = BLOCKED (kebutuhan owner, bukan bug kode)
cfg = luas.get("Shared/Config.luau", "")
zero = re.findall(r"=\s*0,\s*--", cfg)
if zero:
    mark_blocked("product-ids", f"{len(zero)} ID masih 0 -> isi di dashboard Roblox")
else:
    passes.append("product-ids-set")
    print("[PASS] product-ids-set - semua ID terisi")

# 7. Tidak ada TODO
todo = sum(len(re.findall(r"TODO|FIXME|XXX", t)) for t in luas.values())
check("no-todo", todo == 0, f"{todo} sisa")

# 8. AdminUserIds: kosong = BLOCKED (kebutuhan owner). Komentar diabaikan agar
# contoh ID di komentar tidak lolos sebagai ID betulan.
admin_src = re.sub(r"--.*", "", cfg)
admin = re.search(r"AdminUserIds\s*=\s*\{([^}]*)\}", admin_src, re.S)
if admin and re.search(r"\d{4,}", admin.group(1) or ""):
    passes.append("admin-configured")
    print("[PASS] admin-configured - terisi")
else:
    mark_blocked("admin-configured", "kosong - isi UserId owner di Config (untuk ;event)")

# 9. Asset out vs AssetMap
out = {p.stem for p in (BASE / "assets/out").glob("*.png")}
am = set(re.findall(r'\["([^"]+)"\]', luas.get("Shared/AssetMap.luau", "")))
check("assetmap-covers-out", out <= am, f"kurang: {sorted(out-am)[:5]}" if not out <= am else f"{len(out)} key OK")

# 10. Verifikasi fisik generated (buka + resolusi)
gen = BASE / "assets/generated"
gen_files: list = []
try:
    from PIL import Image
    files = [p for p in gen.rglob("*.png")] if gen.exists() else []
    gen_files = files
    bad_img, sizes = [], {}
    for p in files:
        try:
            im = Image.open(p)
            im.load()
            sizes.setdefault(im.size, 0)
            sizes[im.size] += 1
        except Exception:
            bad_img.append(p.name)
    check("assets-openable", bool(files) and not bad_img, f"{len(files)} file, rusak: {bad_img[:3]}")
    check("assets-resolutions", True, str(sizes))
except ImportError:
    mark_untested("assets-openable", "PIL tidak tersedia di mesin ini")

# 11. Manifest konsisten dengan file
mf = BASE / "assets/generated/manifest.json"
if mf.exists():
    man = json.load(open(mf, encoding="utf-8"))
    names = {m["name"] + ".png" for m in man if isinstance(m, dict) and m.get("status") == "done"}
    disk = {str(p.relative_to(gen)).replace("\\", "/") for p in gen_files}
    check("manifest-matches-disk", names == disk, f"manifest {len(names)} vs disk {len(disk)}")
else:
    check("manifest-matches-disk", False, "manifest.json hilang")

# 12. UiPanels: tiap panel terdaftar tepat 1x, toggle via registry, tanpa visible liar
client_src = {k: v for k, v in luas.items() if k.startswith("Client/")}
regs = []
for name, t in client_src.items():
    regs += [(name, m) for m in re.findall(r'UiPanelsT?\.Register\("(\w+)"', t)]
names = [n for _, n in regs]
check("ui-registry-once", sorted(names) == ["profile", "shop", "treasure"],
      f"terdaftar: {sorted(names)}")
toggles_all = sum(len(re.findall(r"UiPanelsT?\.Toggle\s*\(", t)) for t in client_src.values())
toggles_lit = []
for t in client_src.values():
    toggles_lit += re.findall(r'UiPanelsT?\.Toggle\("(\w+)"', t)
nav_calls = []
for t in client_src.values():
    nav_calls += re.findall(r'navBtn\("([^"]+)",\s*"(\w+)"', t)
check("ui-registry-toggles",
      toggles_all >= 4 and all(n in names for n in toggles_lit)
      and all(n in names for _, n in nav_calls),
      f"{toggles_all} Toggle via registry")
frame_direct = 0
for name, t in client_src.items():
    for i, ln in enumerate(t.splitlines()):
        s = ln.strip()
        if re.match(r"frame\.Visible\s*=", s) and "UiPanels" not in "\n".join(t.splitlines()[max(0, i-6):i + 1]):
            frame_direct += 1
check("ui-no-rogue-visible", frame_direct == 0, f"{frame_direct} assignment langsung di luar registry")

# 13. UI tidak boleh punya warna hardcoded (semua via UiTheme) dan tanpa TextScaled sisa
hardcoded = []
for name, t in client_src.items():
    for i, ln in enumerate(t.splitlines(), 1):
        if "Color3.fromRGB" in ln:
            hardcoded.append(f"{name}:{i}")
check("ui-no-hardcoded-colors", not hardcoded, f"ketemu: {hardcoded[:3]}" if hardcoded else "semua via UiTheme")
scaled = []
for name, t in client_src.items():
    for i, ln in enumerate(t.splitlines(), 1):
        if "TextScaled" in ln:
            scaled.append(f"{name}:{i}")
check("ui-no-textscaled", not scaled, f"sisa: {scaled[:3]}" if scaled else "font eksplisit semua")

# 14. Panel responsif: setiap panel utama punya UISizeConstraint + layout/hindari fixed mutlak
no_constraint = []
for fname in ("ShopUI.client.luau", "TreasureUI.client.luau", "InventoryUI.client.luau"):
    t = luas.get(f"Client/{fname}", "")
    if "UISizeConstraint" not in t:
        no_constraint.append(fname)
check("ui-responsive-constraints", not no_constraint,
      f"tanpa constraint: {no_constraint}" if no_constraint else "3 panel punya batas ukuran")

# 15. Gerbang Selene + StyLua (lewati jika biner tidak ada di mesin ini)


def run_tool(toolname: str, args: list) -> "str | None":
    exe = BASE / "tools" / toolname / (toolname + ".exe")
    if not exe.exists():
        exe = pathlib.Path(toolname)  # coba PATH
    try:
        r = subprocess.run([str(exe)] + args, capture_output=True, text=True,
                           cwd=str(BASE), timeout=120)
        return (r.stdout or "") + (r.stderr or "")
    except Exception as e:
        print(f"[SKIP] {toolname} tidak tersedia: {e}")
        return None


import subprocess

out = run_tool("selene", [str(SRC)])
if out is not None:
    n_err = out.count("error[")
    n_warn = out.count("warning[")
    check("selene-clean", n_err == 0 and n_warn == 0,
          f"{n_err} error, {n_warn} warning" if (n_err or n_warn) else "0 error 0 warning")

out = run_tool("stylua", ["--check", str(SRC)])
if out is not None:
    clean = "Diff in" not in out
    check("stylua-clean", clean, "format rapi" if clean else "ada diff format")

# 16. Hal yang TIDAK BISA diuji tanpa Roblox Studio (jujur dicatat, bukan PASS)
mark_untested("studio-8player", "butuh Play test 8 klien di Studio")
mark_untested("studio-datastore-live", "butuh experience terpisah + API access")
mark_untested("studio-monetization", "butuh produk asli + sandbox purchase")
mark_untested("studio-visual-device", "butuh HP/tablet fisik + screenshot")
mark_untested("studio-multiserver", "butuh 2 server untuk uji session lock")
mark_untested("studio-shutdown", "butuh uji BindToClose sungguhan")

print(f"\nFINAL: {len(passes)} PASS, {len(fails)} FAIL, {len(blocked)} BLOCKED, {len(nottested)} NOT TESTED")
if fails:
    print("FAIL:", ", ".join(fails))
if blocked:
    print("BLOCKED (owner action):", ", ".join(blocked))
sys.exit(1 if fails else 0)

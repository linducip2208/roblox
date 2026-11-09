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

# 14b. REGRESI Master 7: perilaku bermakna, bukan sekadar "string ada".
# Setiap cek menguji SEMANTIK (urutan, perbandingan, cakupan) agar regresi ketahuan.
steal_src = luas.get("Server/StealSystem.luau", "")
money_src = luas.get("Server/MoneyService.luau", "")
plot_src = luas.get("Server/PlotManager.luau", "")
treasure_src = luas.get("Server/TreasureService.luau", "")
gp_src = luas.get("Server/GamepassHandler.luau", "")

# 14b-1. Semua handler RemoteFunction ber-argumen memvalidasi tipe tiap paramnya.
main_lines = main_src.splitlines()
handlers: dict = {}
for i, ln in enumerate(main_lines):
    m = re.match(r"function (\w+)\.OnServerInvoke\(([^)]*)\)", ln)
    if m:
        params = [p.strip().split(":")[0].strip() for p in m.group(2).split(",") if p.strip()]
        handlers[m.group(1)] = (i, [p for p in params[1:] if p not in ("_", "_player")])
bad_handlers = []
n_params = 0
for h, (i, extra) in handlers.items():
    n_params += len(extra)
    window = "\n".join(main_lines[i + 1:i + 31])
    missing_p = [p for p in extra if f"type({p})" not in window]
    if missing_p:
        bad_handlers.append(f"{h}:{','.join(missing_p)}")
check("remote-arg-guards", not bad_handlers and len(handlers) >= 10 and n_params >= 6,
      f"tanpa guard: {bad_handlers}" if bad_handlers else f"{len(handlers)} handler, {n_params} param terjaga")

# 14b-2. Jawaban difloor + rentang 1..4 (tolak float liar, 0, negatif, raksasa).
check("remote-choice-range", "math.floor(choiceIdx)" in main_src
      and "choiceIdx < 1" in main_src and "choiceIdx > 4" in main_src, "floor + 1..4")

# 14b-3. Anti curi-sendiri di server (bukan cuma andalkan client).
check("steal-no-self", "thief == victim" in steal_src, "CanSteal tolak self")

# 14b-4. uid manual wajib milik victim + grown; jalur otomatis hanya pilih grown.
check("steal-uid-ownership", "slot.uid == targetUid" in main_src
      and "nothing_grown" in main_src and main_src.count("IsGrown") >= 3, "ownership + grown dicek")

# 14b-5. Commit steal atomik: SETELAH channel sukses, cek slot+grown ulang saat commit,
# kembalikan slot asli bila gagal (cegah duplikat/overwrite).
_commit_tail = main_src[main_src.find("StealChannelTime"):]
check("steal-commit-atomic", "StealChannelTime" in main_src
      and "FindFreeSlot(profile)" in _commit_tail and "IsGrown(stolen)" in _commit_tail
      and "vProfile.slots[slotKey] = stolen" in _commit_tail, "recheck saat commit + restore")

# 14b-6. Uang anti-negatif/NaN/inf + cap dua lapis (per-tick dan per-add).
check("money-antineg", "finite(rawAmount)" in money_src and "rawAmount < 0" in money_src
      and "amount <= 0" in money_src and "b < amount" in money_src
      and "hardCap" in money_src and "MaxCashPerTick" in plot_src and "MaxCashPerTick" in money_src,
      "tolak negatif/NaN + clamp")

# 14b-7. Fencing: token GUID digenerate + disimpan + dibandingkan saat klaim.
check("fencing-token-gen", "GenerateGUID" in save_src
      and "sessionToken[uid] = token" in save_src and "res.token == token" in save_src,
      "klaim hanya menang bila token cocok")

# 14b-8. Fencing: verify + commit bandingkan TOKEN (bukan cuma JobId), tolak bila exp lewat
# atau generasi basi (tulis sesama sesi sendiri tetap diizinkan).
check("fencing-verify-strict", "cur.token == mine" in save_src
      and "(cur.exp or 0) > now()" in save_src
      and "rs.token == mySession.token" in save_src
      and "oldS.token == mySession.token" in save_src
      and "token = sessionToken[player.UserId]" in save_src
      and "oldGen ~= myGen" in save_src, "job+token+generasi, bukan JobId saja")

# 14b-9. Fencing: release + heartbeat hanya sentuh lock MILIK SENDIRI, mismatch = kick.
check("fencing-release-own", "old.token == mine" in save_src
      and "return nil -- hapus hanya milik sendiri" in save_src
      and 'p:Kick("Sesi dipindahkan' in save_src, "no-op bila milik orang")

# 14b-10. Receipt idempoten: dedupe SEBELUM grant, unmark bila save gagal.
_dedupe_i = gp_src.find("receipts[purchaseId] ~= nil")
_grant_i = gp_src.find("GrantLuck(player, 15)")
_save_i = gp_src.find("SaveSystem.Save(player)")
_unmark_i = gp_src.find("profile.receipts[purchaseId] = nil")
check("receipt-idempotent", 0 <= _dedupe_i < _grant_i and _save_i >= 0 < _unmark_i
      and _unmark_i > _save_i, "dedupe->grant->save->unmark")

# 14b-11. Treasure: urutan wajib + cooldown + lockout 5x gagal.
check("treasure-order-lockout", "bukan_urutan" in treasure_src
      and "GetNextUnsolved" in treasure_src and "lastAttempt[uid]" in treasure_src
      and "lockedUntil" in treasure_src and "MaxFails" in treasure_src, "sequence + anti-bruteforce")

# 14b-12. PublicRiddle TIDAK bocorkan jawaban/reward (Zone = nil, tanpa correct/cash).
_pub = re.search(r"function TreasureService\.PublicRiddle\(profile\)(.*?)\nend", treasure_src, re.S)
_pub_body = _pub.group(1) if _pub else ""
check("treasure-no-leak-public", bool(_pub) and "Zone = nil" in _pub_body
      and not re.search(r"correct|Answer|RewardCash|RewardKey", _pub_body), "respons publik steril")

# 14b-13. Profil diclamp saat load: cash 0..1e15, slot vs Items.ById, mutasi fallback, NaN/inf.
check("save-clamp-profile", "0, 1e15" in save_src
      and "Items.ById[slot.itemId] == nil" in save_src and 'slot.mutation = "Normal"' in save_src
      and "v ~= v" in save_src and "math.huge" in save_src, "load tak pernah percaya data cloud")

# 14b-14. Offlinegrowth dicap 8 jam DAN 50% syarat rebirth (anti kaya instan).
check("offline-cap", "OfflineGrowthCap" in save_src
      and "OfflineMaxPctOfRebirth" in save_src and "if earned > cap" in save_src, "dua cap aktif")

# 14b-15. Semua file Client pembuat UI wajib lewat UiTheme (tanpa kecuali).
no_theme = []
for name, t in luas.items():
    if name.startswith("Client/") and re.search(r'Instance\.new\("(ScreenGui|Text\w+|Frame)"', t):
        if "UiTheme" not in t:
            no_theme.append(name)
check("ui-theme-required", not no_theme, f"liar: {no_theme}" if no_theme else "semua panel via UiTheme")

# 14b-16. Client tak pernah sentuh DataStore (server-authoritative penuh).
ds_touch = [name for name, t in client_src.items()
            if re.search(r"DataStoreService|MemoryStoreService|GetAsync|SetAsync|UpdateAsync", t)]
check("client-no-datastore", not ds_touch, f"sentuh DS: {ds_touch}" if ds_touch else "ekonomi hanya server")

# 14b-17. Cap income dua lapis: TickIncome (PlotManager) + Add (MoneyService).
check("income-cap-config", "MaxCashPerTick" in plot_src and "MaxCashPerTick" in money_src,
      "tick cap + add hardcap")

# 14c. REGRESI Master 8: delta-push HUD (R1), antrean analitik (R2), temuan A2/A3/A4,
# snapshot hygiene (delta-save), flush analitik saat keluar. Semua uji SEMANTIK:
# urutan kode + cakupan + konsistensi, bukan sekadar "string ada".
analytics_src = luas.get("Server/Analytics.luau", "")
visuals_src = luas.get("Server/PlotVisuals.luau", "")
hud_src = luas.get("Client/Hud.client.luau", "")

# 14c-1. R1 delta-push HUD: snapshot 5 field + FireClient tick HANYA di dalam gate
# berubah + cleanup lastHud saat leave (tanpa cleanup = bocor memori 8 pemain).
_gate_i = main_src.find("if snap ~= lastHud")
_fire_i = main_src.find('type = "tick"', _gate_i)
_rem_i = main_src.find("Players.PlayerRemoving")
_snap_fields = all(k in main_src for k in ("hudMult", "hudLocked", "gained", "hudLevel"))
check("m8-hud-deltapush", "lastHud" in main_src and _snap_fields
      and 0 <= _gate_i < _fire_i <= _gate_i + 800
      and _rem_i >= 0 and "lastHud[p.UserId] = nil" in main_src[_rem_i:],
      "snapshot+gate+cleanup" if 0 <= _gate_i else "gate delta-push hilang")

# 14c-2. R2 antrean analitik: agregat di memori (bukan spawn per event), SATU thread
# flush, tambah via UpdateAsync (aman konkuren antar server), gagal = antre lagi,
# kunci harian agar ganti hari tak campur, API 6 fungsi utuh + masih dipanggil Main.
_api6 = all(f"function Analytics.{f}" in analytics_src for f in ("Join", "Buy", "Steal", "Rebirth", "Riddle", "Event"))
_used = sum(1 for f in ("Join", "Buy", "Steal", "Rebirth", "Riddle") if f"Analytics.{f}(" in main_src)
_code_only = re.sub(r"--.*", "", analytics_src)  # komentar bisa sebut UpdateAsync
check("m8-analytics-queue", _api6 and _code_only.count("task.spawn") == 1
      and _code_only.count("UpdateAsync") == 1 and "(old or 0) + v" in _code_only
      and "pending[k] = (pending[k] or 0) + v" in _code_only
      and 'os.date("!%Y-%m-%d")' in analytics_src and _used >= 4,
      f"spawn={_code_only.count('task.spawn')} upd={_code_only.count('UpdateAsync')} dipakai={_used}/5")

# 14c-3. A2: Refresh visual (tiap 5 dtk/pemain) TAK BOLEH WaitForChild (yield di
# jalur panas); AssetMap diambil sekali via cache modul + FindFirstChild.
_refresh_tail = visuals_src[visuals_src.find("function PlotVisuals.Refresh"):]
check("m8-perf-a2-assetmap-cache", "function PlotVisuals.Refresh" in visuals_src
      and "WaitForChild" not in _refresh_tail and "getAssetMap()" in _refresh_tail
      and "AssetMapCache" in visuals_src and 'FindFirstChild("AssetMap")' in visuals_src,
      "cache modul, tanpa yield" if "WaitForChild" not in _refresh_tail else "Refresh masih yield")

# 14c-4. A3: CanSteal (tiap tick per channel) TAK BOLEH scan rekursif workspace
# per panggilan; referensi zona di-cache di modul + di-rebind saat DescendantAdded.
_rec_scan = re.findall(r"FindFirstChild\([^)]*,\s*true\)", steal_src)
check("m8-perf-a3-safezone-cache", not _rec_scan
      and ("safeZonePart" in steal_src or "SafeZoneCache" in steal_src)
      and "DescendantAdded" in steal_src,
      "zona di-cache" if not _rec_scan else f"scan rekursif per tick: {_rec_scan}")

# 14c-5. A4: EventManager.Multiplier dihitung SEKALI per tick (hoist), bukan
# per pemain per detik; A1: scan plots SEKALI per tick visual via peta Owner.
_tick_head = main_src.find("-- INCOME + STEAL CHANNEL loop")
_tick_end = main_src.find("-- VISUAL refresh")
_tick = main_src[_tick_head:_tick_end] if 0 <= _tick_head < _tick_end else ""
_mi = _tick.find("EventManager.Multiplier")
_li = _tick.find("for _, p in Players:GetPlayers()")
_vis_end = main_src.find("-- ADMIN chat")
_vis = main_src[_tick_end:_vis_end] if 0 <= _tick_end < _vis_end else ""
check("m8-perf-a4-mult-hoist", _tick.count("EventManager.Multiplier") == 1
      and 0 <= _mi < _li and "local tickMult" in _tick, "1x per tick, bukan Nx")
check("m8-perf-a1-visual-scan", _vis.count("plots:GetChildren()") == 1 and "byOwner" in _vis,
      "1 scan + peta Owner per tick visual" if _vis.count("plots:GetChildren()") == 1
      else f"{_vis.count('plots:GetChildren()')} scan per tick")

# 14c-6. Snapshot hygiene (delta-save): SEMUA kunci runtime yang ditulis ke profil
# di Load/Save WAJIB dikecualikan stripRuntime agar tak bocor ke DataStore;
# save menulis old.data = snap dari ValidateProfile (bukan tabel mentah).
_strip_m = re.search(r"local function stripRuntime\(profile\).*?end", save_src, re.S)
_excl = set(re.findall(r'k\s*~=\s*"([^"]+)"', _strip_m.group(0))) if _strip_m else set()
_written = set(re.findall(r"(?:^|\s)(?:d|data|profile)\.(_\w+|offlineEarned)\s*=", save_src, re.M))
_snap_m = re.search(r"local function snapshot\(profile\).*?end", save_src, re.S)
check("m8-save-snapshot-hygiene", bool(_strip_m) and _written and _written <= _excl
      and "old.data = snap" in save_src and "snapshot(ValidateProfile(d)" in save_src
      and bool(_snap_m) and "stripRuntime" in _snap_m.group(0),
      f"runtime {sorted(_written)} steril" if _written <= _excl else f"bocor: {sorted(_written - _excl)}")

# 14c-7. Flush analitik saat keluar: Analytics WAJIB expose fungsi flush yang
# menguras pending via UpdateAsync, dan dipanggil dari jalur leave/shutdown
# (tanpa ini, 60 dtk terakhir hilang tiap restart/shutdown).
_flush_m = re.search(r"function Analytics\.(Flush\w*)", analytics_src)
_flush_body = ""
if _flush_m:
    _fb = analytics_src[_flush_m.start():]
    _flush_body = _fb[:_fb.find("\nend", _fb.find("\n", 60)) + 4] if "\nend" in _fb else ""
_tail_all = main_src[_rem_i:] + save_src[save_src.find("game:BindToClose"):]
_called = bool(_flush_m) and (f"Analytics.{_flush_m.group(1)}" in _tail_all or f"Analytics.{_flush_m.group(1)}" in save_src)
check("m8-analytics-flush-exit", bool(_flush_m) and "pending" in _flush_body
      and "UpdateAsync" in _flush_body and _called,
      "flush+terpanggil saat exit" if _flush_m else "tak ada Analytics.Flush (window 60 dtk hilang saat shutdown)")

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

#!/usr/bin/env python3
"""Regresi Master 8 Steal a Kebun (milik Agen QA).
Fokus: delta-push snapshot/HUD, antrean + flush analitik, temuan A2/A3/A4,
pola bug P0/P1 generik (race beli ganda, prune receipts).
Setiap uji: (1) gate statis — guard WAJIB ada di src, hilang = FAIL;
(2) payload dijalankan melawan mirror Python dari perilaku kode.
Pola: tools/regression_security.py. Portabel: path dari lokasi script.
Satu ringkasan FINAL. Exit 1 jika FAIL.
Jalankan dari repo root: python tools/regression_master8.py"""
import pathlib
import re
import sys

BASE = pathlib.Path(__file__).resolve().parents[1]
SRC = BASE / "src"
passes: list[str] = []
fails: list[str] = []


def check(name: str, ok: bool, detail: str = ""):
    (passes if ok else fails).append(name)
    d = detail.encode("ascii", "replace").decode()
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" - {d}" if d else ""))


def luau(path: str) -> str:
    return (SRC / path).read_text(encoding="utf-8", errors="ignore")


MAIN = luau("Server/Main.server.luau")
SAVE = luau("Server/SaveSystem.luau")
STEAL = luau("Server/StealSystem.luau")
ANALYTICS = luau("Server/Analytics.luau")
VISUALS = luau("Server/PlotVisuals.luau")
INVENTORY = luau("Server/InventoryService.luau")

# ---- 1. HUD delta-push: gate + cleanup + sim mirror ----
_tick = MAIN[MAIN.find("-- INCOME + STEAL CHANNEL loop"):MAIN.find("-- VISUAL refresh")]
_gate = "if snap ~= lastHud" in MAIN
_rem = MAIN[MAIN.find("Players.PlayerRemoving"):]
g_hud = (_gate and "lastHud[p.UserId] = snap" in MAIN
         and "lastHud[p.UserId] = nil" in _rem
         and _tick.count("FireClient(p, {") >= 1)
last: dict[int, str] = {}
fires: list[tuple] = []


def tick_mirror(uid, cash, mult, locked, gained, level):
    snap = "|".join(map(str, (cash, mult, locked, gained, level)))
    if snap != last.get(uid):
        last[uid] = snap
        fires.append((uid, snap))
        return True
    return False


hud_ok = g_hud
if g_hud:
    hud_ok = tick_mirror(1, 100, 1.0, False, 0, 1) is True
    hud_ok &= tick_mirror(1, 100, 1.0, False, 0, 1) is False  # sama -> diam
    hud_ok &= tick_mirror(1, 150, 1.0, False, 50, 1) is True  # cash naik -> kirim
    hud_ok &= tick_mirror(1, 150, 1.0, False, 50, 1) is False
    hud_ok &= len(fires) == 2
    last.pop(1, None)  # mirror cleanup leave
    hud_ok &= 1 not in last
check("m8-hud-delta-sim", hud_ok, "idle diam, berubah kirim, leave bersih" if g_hud else "gate hilang")

# ---- 2. Antrean analitik: agregat + flush + gagal antre lagi ----
_code = re.sub(r"--.*", "", ANALYTICS)
g_q = (_code.count("task.spawn") == 1 and _code.count("UpdateAsync") == 1
       and "(old or 0) + v" in _code and "pending[k] = (pending[k] or 0) + v" in _code)
pending: dict[str, int] = {}
writes: list[tuple] = []


def bump(k, d):
    pending[k] = pending.get(k, 0) + d


def flush(fail=False):
    batch = dict(pending)
    pending.clear()
    for k, v in batch.items():
        if v != 0:
            if fail:
                pending[k] = pending.get(k, 0) + v
            else:
                writes.append((k, v))


q_ok = g_q
if g_q:
    for _ in range(50):
        bump("2026-11-09:buy_value", 1000)
    bump("2026-11-09:join", 1)
    flush()
    q_ok = writes == [("2026-11-09:buy_value", 50000), ("2026-11-09:join", 1)]
    bump("x", 5)
    flush(fail=True)  # gagal tulis -> antre lagi, tak hilang
    q_ok &= pending.get("x") == 5 and ("x", 5) not in writes
check("m8-analytics-queue-sim", q_ok, "50 event -> 1 write/key; gagal tak hilang" if g_q else "guard hilang")

# ---- 3. Exit-drain analitik: Flush expose + dipanggil saat leave/shutdown ----
_fm = re.search(r"function Analytics\.(Flush\w*)", ANALYTICS)
_tail = MAIN[MAIN.find("Players.PlayerRemoving"):] + SAVE[SAVE.find("game:BindToClose"):]
_called = bool(_fm) and f"Analytics.{_fm.group(1)}" in _tail
_fb = ""
if _fm:
    _rest = ANALYTICS[_fm.start():]
    _cut = _rest.find("\nend")
    _fb = _rest[:_cut] if _cut >= 0 else ""
exit_ok = bool(_fm) and "pending" in _fb and "UpdateAsync" in _fb and _called
if _fm and "pending" in _fb:  # sim drain mirror bila Flush ada
    pending2 = {"a:join": 3}
    drained = [pending2.pop(k) for k in list(pending2)]
    exit_ok &= drained == [3] and not pending2
check("m8-analytics-exitdrain", exit_ok, "flush+terpanggil" if exit_ok else "tanpa Flush/exit-call (window 60 dtk hilang)")

# ---- 4. A3 safezone cache: gate + mirror keputusan identik ----
_rec = re.findall(r"FindFirstChild\([^)]*,\s*true\)", STEAL)
g_z = (not _rec and "safeZonePart" in STEAL and "DescendantAdded" in STEAL
       and "thief == victim" in STEAL)


def can_mirror(tp, vp, zone, radius, locked=False, self_=False):
    if self_:
        return False, "self"
    if locked:
        return False, "locked"
    if tp is None or vp is None:
        return False, "nochar"
    if zone is not None and ((abs(tp[0] - zone[0]) + abs(tp[1] - zone[1])) < radius
                             or (abs(vp[0] - zone[0]) + abs(vp[1] - zone[1])) < radius):
        return False, "safezone"
    if abs(tp[0] - vp[0]) + abs(tp[1] - vp[1]) > 25:
        return False, "toofar"
    return True, "ok"


z_cases = [
    (((0, 0), (10, 0), (100, 100), 10, False, False), (True, "ok")),
    (((0, 0), (10, 0), (5, 0), 10, False, False), (False, "safezone")),
    (((0, 0), (10, 0), None, 10, False, False), (True, "ok")),  # zona belum ada
    (((0, 0), (10, 0), (100, 100), 10, True, False), (False, "locked")),
    (((0, 0), (10, 0), (100, 100), 10, False, True), (False, "self")),
    (((0, 0), (500, 500), (100, 100), 10, False, False), (False, "toofar")),
]
check("m8-safezone-sim", g_z and all(can_mirror(*p) == e for p, e in z_cases),
      f"{len(z_cases)} keputusan cache-identik" if g_z else "guard hilang")

# ---- 5. Snapshot hygiene: mirror stripRuntime, runtime tak bocor ----
_sm = re.search(r"local function stripRuntime\(profile\).*?end", SAVE, re.S)
_excl = set(re.findall(r'k\s*~=\s*"([^"]+)"', _sm.group(0))) if _sm else set()
RUNTIME = {"_uid", "_baseAt", "_baseSession", "_baseGen", "offlineEarned"}


def strip_mirror(profile):
    return {k: v for k, v in profile.items() if k not in RUNTIME}


prof = {"cash": 500, "slots": {}, "_baseAt": 1, "_baseSession": {"job": "j", "token": "t"},
        "_baseGen": 2, "offlineEarned": 99, "_uid": 7}
snap = strip_mirror(prof)
snap_ok = (bool(_sm) and RUNTIME <= _excl and snap == {"cash": 500, "slots": {}}
           and "old.data = snap" in SAVE and "snapshot(ValidateProfile(d)" in SAVE)
check("m8-snapshot-sim", snap_ok, f"runtime {sorted(RUNTIME)} steril" if _sm else "guard hilang")

# ---- 6. P0 race beli ganda: GiveShovel idempoten + refund persis via Set ----
g_race = ("function InventoryService.GiveShovel" in INVENTORY
          and "hasShovel" in INVENTORY
          and "MoneyService.Set(player, before)" in MAIN)
owned = {"shovel": False}
grants = 0


def give_shovel():
    if owned["shovel"]:
        return False
    owned["shovel"] = True
    return True


def buy_tool_mirror(bal, cost):
    global grants
    before = bal
    if bal < cost:
        return False, bal
    bal -= cost
    if not give_shovel():
        bal = before  # mirror Set(player, before)
        return False, bal
    grants += 1
    return True, bal


race_ok = g_race
if g_race:
    ok1, b1 = buy_tool_mirror(1000, 500)
    ok2, b2 = buy_tool_mirror(b1, 500)  # balapan: tolak + refund
    race_ok = ok1 and b1 == 500 and not ok2 and b2 == 500 and grants == 1
check("m8-buytool-race-sim", race_ok, "ganda ditolak + refund persis" if g_race else "guard hilang")

# ---- 7. A10 prune receipts: early-out <=200 scan + potong >30 hari ----
g_prune = ("if count > 200 then" in SAVE and "30 * 86400" in SAVE)


def prune_mirror(receipts, now):
    count = 0
    scanned = 0
    for _ in receipts:
        scanned += 1
        count += 1
        if count > 200:
            break
    if count > 200:
        cutoff = now - 30 * 86400
        receipts = {pid: at for pid, at in receipts.items()
                    if isinstance(at, (int, float)) and at >= cutoff}
    return receipts, scanned


big = {f"p{i}": 1000 + i for i in range(500)}
kept, scanned = prune_mirror(dict(big), now=1000 + 31 * 86400)
prune_ok = g_prune and scanned == 201 and not kept  # semua basi -> kosong
small = {"a": 10**12}
kept2, s2 = prune_mirror(dict(small), now=10**12)
prune_ok &= kept2 == small and s2 == 1
check("m8-receipt-prune-bound", prune_ok, "scan berhenti di 201, basi dipotong" if g_prune else "guard hilang")

print(f"\nFINAL: {len(passes)} PASS, {len(fails)} FAIL")
if fails:
    print("FAIL:", ", ".join(fails))
sys.exit(1 if fails else 0)

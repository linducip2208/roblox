#!/usr/bin/env python3
"""Regresi gameplay Steal a Kebun (milik Agen QA).
Memanggil tools existing (ui-audit, check-rarity, sim_economy) + simulasi
pacing bermakna. Portabel: path dari lokasi script.
Kategori: PASS/FAIL. Satu ringkasan FINAL. Exit nonzero hanya jika FAIL.
Jalankan dari repo root: python tools/regression_gameplay.py"""
import math
import pathlib
import re
import subprocess
import sys

BASE = pathlib.Path(__file__).resolve().parents[1]
TOOLS = BASE / "tools"
SRC = BASE / "src"
passes: list[str] = []
fails: list[str] = []


def check(name: str, ok: bool, detail: str = ""):
    (passes if ok else fails).append(name)
    d = detail.encode("ascii", "replace").decode()
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" - {d}" if d else ""))


def run_tool(fname: str):
    try:
        r = subprocess.run([sys.executable, str(TOOLS / fname)],
                           capture_output=True, text=True, cwd=str(BASE), timeout=300)
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except Exception as e:
        return 99, f"tidak bisa jalan: {e}"


def luau(path: str) -> str:
    return (SRC / path).read_text(encoding="utf-8", errors="ignore")


# 1-3. Tools existing (dipanggil, bukan diduplikat).
rc, out = run_tool("ui-audit.py")
check("tool-ui-audit", rc == 0, out.strip().splitlines()[-1] if out.strip() else f"rc={rc}")

rc, out = run_tool("check-rarity.py")
check("tool-check-rarity", rc == 0 and "tak tercover: []" in out,
      out.strip().replace("\n", " ")[:160])

rc, sim_out = run_tool("sim_economy.py")
m = re.search(r"(\d+)/(\d+) lolos", sim_out)
sim_ok = rc == 0 and bool(m) and m.group(1) == m.group(2) and m.group(1) != "0"
check("tool-sim-economy", sim_ok, m.group(0) if m else f"rc={rc}")

# 4. Pacing: semua profil mencapai rebirth-1 <= hari ke-7 dan rebirth-3 ada.
rebirth_days: dict[str, list[tuple[int, int]]] = {}
for ln in sim_out.splitlines():
    mm = re.match(r"(.+?):\s*(.*)", ln)
    if mm and "rebirth-1" in mm.group(2):
        rebirth_days[mm.group(1)] = re.findall(r"rebirth-(\d) hari-(\d+)", mm.group(2))
paced = bool(rebirth_days) and all(
    any(r == "1" and int(d) <= 7 for r, d in v) and any(r == "3" for r, _ in v)
    for v in rebirth_days.values())
check("sim-pacing-rebirth", paced, f"{len(rebirth_days)} profil capai r3")

# 5. EV mutasi Config == EV yang dipakai sim (tak ada inflate diam-diam).
cfg = luau("Shared/Config.luau")
mr = dict(re.findall(r"(\w+)\s*=\s*(\d+)", cfg.split("MutationRate")[1].split("}")[0])) \
    if "MutationRate" in cfg else {}
mm_ = dict(re.findall(r"(\w+)\s*=\s*(\d+)", cfg.split("Mutations")[1].split("}")[0])) \
    if "Mutations" in cfg else {}
ev_cfg = sum(int(mr.get(k, 0)) / 100.0 * int(mm_.get(k, 0)) for k in mr) if mr else 0.0
msim = re.search(r"EV mutasi dipakai:\s*([\d.]+)x", sim_out)
ev_sim = float(msim.group(1)) if msim else -1.0
check("mutation-ev-match", mr and abs(ev_cfg - ev_sim) < 1e-9, f"config {ev_cfg} vs sim {ev_sim}")

# 6. Total reward riddle < syarat rebirth (riddle bantu, tak gantikan main loop).
tcfg = luau("Shared/TreasureConfig.luau")
total_riddle = sum(int(x.replace("_", "")) for x in re.findall(r"RewardCash\s*=\s*([\d_]+)", tcfg))
mreq = re.search(r"RebirthRequirement\s*=\s*([\d_]+)", cfg)
req0 = int(mreq.group(1).replace("_", "")) if mreq else 0
check("treasure-pacing", 0 < total_riddle < req0, f"riddle total {total_riddle} vs rebirth {req0}")

# 7. Cap offline 50% MENGIKAT di late game (bukan hiasan).
items = luau("Shared/Items.luau")
blocks = re.findall(r"\{([^{}]*?Id\s*=\s*\"[^\"]+\"[^{}]*?)\}", items, re.S)
cps_list = [int(x) for b in blocks for x in re.findall(r"CashPerSec\s*=\s*(\d+)", b)]
mcap = re.search(r"MaxSlots\s*=\s*(\d+)", cfg)
mmoult = re.search(r"MaxRebirthMultiplier\s*=\s*(\d+)", cfg)
moff = re.search(r"OfflineMaxPctOfRebirth\s*=\s*([\d.]+)", cfg)
moffh = re.search(r"OfflineGrowthCap\s*=\s*(\d+)\s*\*\s*3600", cfg)
best = max(cps_list) if cps_list else 0
slots = int(mcap.group(1)) if mcap else 8
maxmult = int(mmoult.group(1)) if mmoult else 10
pct = float(moff.group(1)) if moff else 0.5
offh = int(moffh.group(1)) if moffh else 8
uncapped = best * slots * maxmult * offh * 3600
cap = math.floor(req0 * pct)
check("offline-cap-binds", best > 0 and uncapped > cap > 0,
      f"uncapped {uncapped} vs cap {cap}")

# 8. Syarat rebirth linear (tiap rebirth +1x basis, tak ada rebirth gratis).
mfn = re.search(r"RebirthRequirementFor.*?\n.*?return\s+(.+)", cfg)
linear = mfn and "RebirthRequirement * (math.max(rebirths, 0) + 1)" in mfn.group(1)
req = lambda r: req0 * (max(r, 0) + 1)
check("rebirth-scale-linear", bool(linear) and req0 > 0
      and (req(1) - req(0)) == (req(2) - req(1)) == req0,
      f"r0={req(0)} r1={req(1)} r2={req(2)}")

# 9. Tier Secret hanya via steal: server tolak beli + client sembunyikan.
main = luau("Server/Main.server.luau")
shopui = luau("Client/ShopUI.client.luau")
secret_block = [b for b in blocks if 'Rarity = "Secret"' in b]
secret_ids = re.findall(r'Id\s*=\s*"([^"]+)"', " ".join(secret_block))
check("secret-not-sellable", bool(secret_ids) and "secret_only_steal" in main
      and 'Rarity == "Secret"' in shopui, f"{len(secret_ids)} id Secret via steal")

print(f"\nFINAL: {len(passes)} PASS, {len(fails)} FAIL")
if fails:
    print("FAIL:", ", ".join(fails))
sys.exit(1 if fails else 0)

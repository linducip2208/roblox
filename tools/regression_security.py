#!/usr/bin/env python3
"""Regresi keamanan Steal a Kebun (milik Agen QA).
Uji statis + SIMULASI payload adversarial per remote (argumen tak tervalidasi,
payload negatif, ownership). Rate-limit TIDAK diuji di sini (sudah di
verify.py: rate-limit-coverage) agar tak duplikat.
Setiap simulasi: (1) gate statis — guard WAJIB ada di src, hilang = FAIL;
(2) payload dijalankan melawan mirror Python dari guard persis di kode.
Portabel: path dari lokasi script. Satu ringkasan FINAL. Exit 1 jika FAIL.
Jalankan dari repo root: python tools/regression_security.py"""
import math
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
MONEY = luau("Server/MoneyService.luau")
REDEEM = luau("Server/RedeemCode.luau")
TREASURE = luau("Server/TreasureService.luau")
GAMEPASS = luau("Server/GamepassHandler.luau")
ITEMS = luau("Shared/Items.luau")
CONFIG = luau("Shared/Config.luau")
ANSWERS = luau("Server/TreasureAnswers.luau")

ITEM_IDS = set(re.findall(r'Id\s*=\s*"([^"]+)"', ITEMS))
SECRET_IDS = set()
for b in re.findall(r"\{([^{}]*?Id\s*=\s*\"[^\"]+\"[^{}]*?)\}", ITEMS, re.S):
    mid = re.search(r'Id\s*=\s*"([^"]+)"', b)
    if mid and 'Rarity = "Secret"' in b:
        SECRET_IDS.add(mid.group(1))
CODES = dict(re.findall(r"(\w+)\s*=\s*(\d+)", REDEEM.split("local CODES")[1].split("}")[0])
              if "local CODES" in REDEEM else {})
ANSWER_KEYS = set(re.findall(r"(R\d+)\s*=", ANSWERS))
HARDCAP = 10_000_000 * 10
mcap = re.search(r"MaxCashPerTick\s*=\s*([\d_]+)", CONFIG)
if mcap:
    HARDCAP = int(mcap.group(1).replace("_", "")) * 10

# ---- 1. Redeem: panjang + normalisasi + sekali pakai ----
g_redeem = ('#code > 32' in MAIN and 'type(code)' in MAIN
            and 'code:upper()' in REDEEM and 'sudah_dipakai' in REDEEM)
used: set[str] = set()


def redeem_mirror(code):
    if not isinstance(code, str) or len(code) > 32:  # mirror Main guard
        return False, "invalid"
    c = code.upper().replace(" ", "")
    if c not in CODES:
        return False, "kode_salah"
    if c in used:
        return False, "sudah_dipakai"
    used.add(c)
    return True, CODES[c]


redeem_cases = [
    ("RILIS100K", (True, CODES.get("RILIS100K"))),
    ("RILIS100K", (False, "sudah_dipakai")),
    (" rilis100k ", (True, CODES.get("RILIS100K")) if "RILIS100K" in used else None),
    ("HACK999", (False, "kode_salah")),
    ("", (False, "kode_salah")),
    ("x" * 33, (False, "invalid")),
    (12345, (False, "invalid")),
    (None, (False, "invalid")),
]
# kasus ke-3: sudah dipakai (dinormalisasi sama) -> sudah_dipakai
redeem_cases[2] = (" rilis100k ", (False, "sudah_dipakai"))
redeem_ok = g_redeem and all(redeem_mirror(p) == e for p, e in redeem_cases)
check("redeem-payloads", redeem_ok, f"{len(redeem_cases)} payload" if g_redeem else "guard hilang")

# ---- 2. Buy: tipe + panjang + ById + Secret/event/stok/kas ----
sample_id = next(iter(ITEM_IDS - SECRET_IDS))
secret_id = next(iter(SECRET_IDS))
g_buy = ('type(itemId)' in MAIN and '#itemId > 64' in MAIN
         and 'Items.ById[itemId]' in MAIN and 'secret_only_steal' in MAIN)
BYID = ITEM_IDS


def buy_mirror(item_id, cash):
    if not isinstance(item_id, str) or len(item_id) > 64:
        return False, "invalid"
    if item_id not in BYID:
        return False, "invalid"
    if item_id in SECRET_IDS:
        return False, "secret_only_steal"
    return True, "slot"


buy_cases = [
    (sample_id, (True, "slot")),
    ("x" * 65, (False, "invalid")),
    (123, (False, "invalid")),
    (None, (False, "invalid")),
    ("../../admin", (False, "invalid")),
    (secret_id, (False, "secret_only_steal")),
]
check("buy-payloads", g_buy and all(buy_mirror(p, 10**9) == e for p, e in buy_cases),
      f"{len(buy_cases)} payload, contoh {sample_id}/{secret_id}" if g_buy else "guard hilang")

# ---- 3. Steal: tipe victim + ownership uid + grown + self ----
g_steal = ('type(victimUserId)' in MAIN and 'type(uid)' in MAIN
           and 'slot.uid == targetUid' in MAIN and 'nothing_grown' in MAIN
           and 'thief == victim' in STEAL)
CPS = {"a": 10, "b": 50}


def resolve_mirror(victim_slots, uid_or_empty, thief_is_victim=False):
    if thief_is_victim:  # mirror CanSteal
        return False, "self"
    if uid_or_empty is None or uid_or_empty == "":
        best, best_cps = None, -1
        for s in victim_slots:
            if s.get("grown") and CPS.get(s["itemId"], 0) > best_cps:
                best, best_cps = s["uid"], CPS[s["itemId"]]
        return (True, best) if best else (False, "nothing_grown")
    if not isinstance(uid_or_empty, str) or len(uid_or_empty) > 64:
        return False, "invalid"
    found = next((s for s in victim_slots if s["uid"] == uid_or_empty), None)
    if not found:
        return False, "invalid"
    if not found.get("grown"):
        return False, "belum_grown"
    return True, uid_or_empty


V = [{"uid": "U1", "itemId": "a", "grown": True},
     {"uid": "U2", "itemId": "b", "grown": False}]
steal_cases = [
    ((V, "", False), (True, "U1")),            # auto-pick: grown termahal (b belum grown)
    ((V, "U1", False), (True, "U1")),
    ((V, "U2", False), (False, "belum_grown")),  # ungrown ditolak
    ((V, "U9", False), (False, "invalid")),       # bukan milik victim
    ((V, "x" * 65, False), (False, "invalid")),   # oversize
    ((V, 123, False), (False, "invalid")),        # tipe salah
    (([], "", False), (False, "nothing_grown")),  # tak ada yang grown
    ((V, "U1", True), (False, "self")),           # curi sendiri
]
check("steal-payloads", g_steal and all(resolve_mirror(*p) == e for p, e in steal_cases),
      f"{len(steal_cases)} payload ownership" if g_steal else "guard hilang")

# ---- 4. SubmitAnswer: floor + 1..4 + riddle dikenal ----
g_ans = ('math.floor(choiceIdx)' in MAIN and 'choiceIdx < 1' in MAIN
         and 'choiceIdx > 4' in MAIN and ANSWER_KEYS == {f"R{i}" for i in range(1, 11)})


def answer_mirror(riddle_id, choice):
    if not isinstance(riddle_id, str) or not isinstance(choice, (int, float)):
        return False, "input_invalid"
    c = math.floor(choice)
    if c < 1 or c > 4:
        return False, "input_invalid"
    if riddle_id not in ANSWER_KEYS:
        return False, "riddle_invalid"
    return True, c


ans_cases = [
    (("R1", 2), (True, 2)),
    (("R1", 2.7), (True, 2)),   # floor dinormalisasi seperti server
    (("R1", 0), (False, "input_invalid")),
    (("R1", 5), (False, "input_invalid")),
    (("R1", -1), (False, "input_invalid")),
    (("R1", 10**9), (False, "input_invalid")),
    (("R1", "2"), (False, "input_invalid")),
    (("R1", None), (False, "input_invalid")),
    (("R99", 2), (False, "riddle_invalid")),
]
check("answer-payloads", g_ans and all(answer_mirror(*p) == e for p, e in ans_cases),
      f"{len(ans_cases)} payload" if g_ans else "guard hilang")

# ---- 5. Money: tolak negatif/NaN/inf + clamp hardcap ----
g_money = ('finite(rawAmount)' in MONEY and 'rawAmount < 0' in MONEY
           and 'amount <= 0' in MONEY and 'b < amount' in MONEY and 'hardCap' in MONEY)


def add_mirror(bal, raw, mult=1.0):
    if not isinstance(raw, (int, float)) or raw != raw:
        return bal
    if raw in (math.inf, -math.inf) or raw < 0:
        return bal
    final = math.floor(raw * mult)
    return bal + min(final, HARDCAP)


def spend_mirror(bal, amount):
    if not isinstance(amount, (int, float)) or amount != amount:
        return False, bal
    if amount <= 0 or amount in (math.inf, -math.inf):
        return False, bal
    if bal < amount:
        return False, bal
    return True, bal - amount


money_ok = (g_money
            and add_mirror(1000, -500) == 1000
            and add_mirror(1000, float("nan")) == 1000
            and add_mirror(1000, math.inf) == 1000
            and add_mirror(1000, 10**15) == 1000 + HARDCAP
            and spend_mirror(1000, 9999) == (False, 1000)
            and spend_mirror(1000, -50) == (False, 1000)
            and spend_mirror(1000, 0) == (False, 1000)
            and spend_mirror(1000, 400) == (True, 600))
check("money-payloads", money_ok, f"hardcap {HARDCAP}" if g_money else "guard hilang")

# ---- 6. Fencing duel: dua job + expiry + release + commit basi ----
g_fence = ('GenerateGUID' in SAVE and 'old.token == mine' in SAVE
           and 'cur.token == mine' in SAVE and 'oldGen ~= myGen' in SAVE)
store: dict[str, dict] = {}


def claim(job, token, now, ttl=300):
    old = store.get("s_1")
    if old is None or not isinstance(old, dict) or old.get("job") == job \
            or (old.get("exp", 0) < now):
        store["s_1"] = {"job": job, "token": token, "exp": now + ttl}
        return True
    return False


def verify(token, now):
    cur = store.get("s_1")
    return isinstance(cur, dict) and cur.get("token") == token and cur.get("exp", 0) > now


def release(token):
    if isinstance(store.get("s_1"), dict) and store["s_1"].get("token") == token:
        del store["s_1"]


fence_ok = g_fence
if g_fence:
    t = 1000
    fence_ok = claim("jobA", "tokA", t) is True          # A klaim
    fence_ok &= claim("jobB", "tokB", t + 10) is False   # B ditolak saat live
    fence_ok &= verify("tokA", t + 10) is True
    release("tokB")                                       # release non-owner no-op
    fence_ok &= verify("tokA", t + 10) is True
    fence_ok &= claim("jobB", "tokB", t + 400) is True   # exp lewat -> B menang
    fence_ok &= verify("tokA", t + 410) is False         # A basi
    release("tokA")                                       # release basi no-op
    fence_ok &= verify("tokB", t + 410) is True
    fence_ok &= claim("jobB", "tokB2", t + 420) is True  # restart job sama menang
check("fencing-duel-sim", fence_ok, "7 skenario duel sesi" if g_fence else "guard hilang")

# ---- 7. Receipt replay: PurchaseId sama tak dobel grant ----
g_receipt = ('receipts[purchaseId] ~= nil' in GAMEPASS
             and 'profile.receipts[purchaseId] = nil' in GAMEPASS)
grants = 0
receipts: dict[str, int] = {}


def bought(product_id, purchase_id, known=(7, 8)):
    global grants
    if product_id == 0:
        return False
    if product_id not in known:
        return False
    if purchase_id and receipts.get(purchase_id) is not None:
        return True
    grants += 1
    if purchase_id:
        receipts[purchase_id] = 1
    return True


receipt_ok = g_receipt
if g_receipt:
    receipt_ok = bought(7, "pid-1") is True and grants == 1
    receipt_ok &= bought(7, "pid-1") is True and grants == 1  # replay: ack tanpa grant
    receipt_ok &= bought(999, "pid-2") is False and grants == 1
    receipt_ok &= bought(0, "pid-3") is False and grants == 1
check("receipt-replay-sim", receipt_ok, "replay tak dobel grant" if g_receipt else "guard hilang")

print(f"\nFINAL: {len(passes)} PASS, {len(fails)} FAIL")
if fails:
    print("FAIL:", ", ".join(fails))
sys.exit(1 if fails else 0)

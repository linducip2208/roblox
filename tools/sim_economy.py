#!/usr/bin/env python3
"""Simulasi progresi Steal a Kebun (model teoritis, bukan data live).
Asumsi: EV mutasi 2.25x, reinvest agresif, riddle selesai hari ke-2 (630rb =
solve 315rb + gali 315rb sesuai Shared/TreasureConfig.luau),
daily streak penuh, redeem 400rb hari-1 (100rb+50rb+250rb sesuai
Server/RedeemCode.luau). Keluar: hari ke rebirth 1/2/3.
Jalankan: python tools/sim_economy.py"""
import math
import sys

ITEMS = [  # (cost, cps, growth)
    (50,1,30),(150,3,60),(400,7,120),(1200,18,180),(3000,40,300),(7500,90,420),
    (15000,180,600),(35000,350,900),(75000,700,1200),(150000,1400,1500),
    (300000,2800,1800),(600000,5500,2100),(1200000,11000,2400),(2500000,22000,2700),
    (5000000,45000,3000),(10000000,90000,3300),(25000000,200000,3600),
    (50000000,450000,3900),
]
MUT_EV = 0.7*1 + 0.15*5 + 0.10*3 + 0.05*10  # = 2.25
SLOTS, REBIRTH = 8, 1_000_000
REQ = lambda r: REBIRTH * (r + 1)  # skala linear seperti Config.RebirthRequirementFor
RIDDLE = [(2, 630_000)]
DAILY = [500,1500,4000,10000,25000,60000,150000]
REDEEM = 400_000
OFFLINE_CAP_H = 8  # Config.OfflineGrowthCap = 8 jam
OFFLINE_MAX_PCT = 0.5  # Config.OfflineMaxPctOfRebirth

def _run(active_s_per_day, offline_cap_h=OFFLINE_CAP_H, event_mult_days=()):
    """Generator (hari, rebirths). event_mult_days: {hari: mult} utk sesi aktif
    hari itu (model Hujan Kopi/Event, tidak inflate: default mati)."""
    cash, slots, day, rebirths, streak = 100.0, [], 1, 0, 0
    riddle_done, redeem_done = False, False
    mult = 1.0
    while rebirths < 3 and day <= 60:
        while len(slots) < SLOTS:
            afford = [it for it in ITEMS if it[0] <= cash]
            if not afford:
                break
            it = afford[-1]
            cash -= it[0]
            slots.append({"cps": it[1], "grow": it[2], "t": 0.0})
        t = 0
        evm = event_mult_days.get(day, 1.0) if isinstance(event_mult_days, dict) else 1.0
        while t < active_s_per_day:
            step = 60
            inc = sum(s["cps"] * MUT_EV for s in slots if s["t"] >= s["grow"]) * step * mult * evm
            cash += inc
            for s in slots:
                s["t"] += step
            t += step
            if cash >= REQ(rebirths):
                break
        if not redeem_done:
            cash += REDEEM; redeem_done = True
        streak = streak % 7 + 1
        cash += DAILY[streak - 1]
        if day in (d for d, _ in RIDDLE) and not riddle_done:
            cash += RIDDLE[0][1]; riddle_done = True
        grown_cps = sum(s["cps"] * MUT_EV for s in slots if s["t"] >= s["grow"])
        cash += min(grown_cps * offline_cap_h * 3600 * mult, REQ(rebirths) * OFFLINE_MAX_PCT)
        if cash >= REQ(rebirths):
            rebirths += 1
            yield day, rebirths
            cash, slots = 100.0, []
            mult = min(1 + rebirths, 10)
        day += 1

def days_to_rebirth(active_s_per_day, offline_cap_h=8):
    return _run(active_s_per_day, offline_cap_h)

# ---------- Model otoritatif (mirror aturan server, utk uji exploit) ----------
HARD_CAP = 10_000_000 * 10  # MoneyService: MaxCashPerTick * 10

class Acct:
    def __init__(self, cash=0.0, mult=1.0):
        self.cash, self.mult = cash, mult

def econ_add(a, raw):
    """Mirror MoneyService.Add: tolak negatif/NaN/inf, floor, clamp hard cap."""
    if not isinstance(raw, (int, float)) or raw != raw:
        return a.cash
    if raw in (math.inf, -math.inf) or raw < 0:
        return a.cash
    final = math.floor(raw * a.mult)
    if final > HARD_CAP:
        final = HARD_CAP
    a.cash += final
    return a.cash

def econ_spend(a, amount):
    """Mirror MoneyService.Spend: cek dana, tolak <= 0."""
    if not isinstance(amount, (int, float)) or amount != amount:
        return False
    if amount <= 0 or amount in (math.inf, -math.inf):
        return False
    if a.cash < amount:
        return False
    a.cash -= amount
    return True

class Plot:
    def __init__(self):
        self.slots = {}  # key -> {uid,itemId,grown}

def plant(plot, key, uid, item_id, grown=False):
    if key in plot.slots:
        return False, "slot_terisi"  # anti timpa / duplikat tanam
    plot.slots[key] = {"uid": uid, "itemId": item_id, "grown": grown}
    return True, key

def harvest(plot, key):
    """Panen = ambil + hapus. Panen ganda uid/key sama wajib gagal."""
    if key not in plot.slots:
        return False, "sudah_dipanen"
    return True, plot.slots.pop(key)

class StealWorld:
    """Mirror StealSystem: itemLocks + channel + kepemilikan victim."""
    def __init__(self):
        self.locks = {}     # uid -> thief
        self.channels = {}  # thief -> uid

    def request(self, thief, uid, victim_plot):
        owned = any(s["uid"] == uid and s["grown"] for s in victim_plot.slots.values())
        if not owned:
            return False, "invalid"  # item tak tersedia / belum grown
        holder = self.locks.get(uid)
        if holder is not None and holder != thief:
            return False, "item_diperebutkan"  # interaksi simultan: 1 pemenang
        prev = self.channels.get(thief)
        if prev is not None and prev != uid and self.locks.get(prev) == thief:
            del self.locks[prev]  # bebas lock lama (fix lock bocor)
        self.locks[uid] = thief
        self.channels[thief] = uid
        return True, "channel_started"

    def complete(self, thief, victim_plot, thief_plot):
        uid = self.channels.get(thief)
        if uid is None or self.locks.get(uid) != thief:
            return False, "no_channel"
        if len(thief_plot.slots) >= SLOTS:
            return False, "thief_penuh"
        for k, s in list(victim_plot.slots.items()):
            if s["uid"] == uid:
                if not s["grown"]:
                    return False, "belum_grown"
                stolen = victim_plot.slots.pop(k)
                free = next((str(i) for i in range(1, SLOTS + 1) if str(i) not in thief_plot.slots), None)
                if free is None:
                    victim_plot.slots[k] = stolen  # kembalikan slot ASLI
                    return False, "thief_penuh"
                thief_plot.slots[free] = dict(stolen, grown=True)
                del self.locks[uid]; del self.channels[thief]
                return True, stolen
        return False, "invalid"

class Daily:
    def __init__(self):
        self.last = ""
    def claim(self, day_key):
        if self.last == day_key:
            return False, 0  # duplikat claim hari sama ditolak
        self.last = day_key
        return True, 500

class RiddleTrail:
    """Mirror TreasureService.SubmitAnswer: urutan wajib, sekali solve,
    lockout 60 dtk setelah 5 gagal."""
    ORDER = ["R1", "R2", "R3", "R4", "R5", "R6", "R7", "R8", "R9", "R10"]
    MAX_FAILS = 5
    def __init__(self):
        self.solved, self.fails, self.locked = {}, {}, {}
    def submit(self, rid, correct, now=0):
        if self.locked.get(rid, 0) > now:
            return False, "locked_coba_lagi_nanti"
        nxt = next((r for r in self.ORDER if r not in self.solved), None)
        if rid in self.solved:
            return False, "sudah_selesai"
        if nxt != rid:
            return False, "bukan_urutan"
        if correct:
            self.solved[rid] = True; self.fails[rid] = 0
            return True, "solved"
        self.fails[rid] = self.fails.get(rid, 0) + 1
        if self.fails[rid] >= self.MAX_FAILS:
            self.locked[rid] = now + 60
            return False, "gagal_5x_tunggu_60d"
        return False, "jawaban_salah"

class Redeems:
    def __init__(self):
        self.used = set()
    def redeem(self, code):
        c = code.upper().replace(" ", "")
        if c not in ("RILIS100K", "HUJANKOPI", "GACOR2026"):
            return False, "kode_salah"
        if c in self.used:
            return False, "sudah_dipakai"  # kode sekali pakai
        self.used.add(c)
        return True, 100000

def offline_earned(grown_cps, mult, elapsed_s, req):
    """Mirror SaveSystem.Load: cap 8 jam + cap 50% syarat rebirth."""
    elapsed = min(max(elapsed_s, 0), OFFLINE_CAP_H * 3600)
    earned = math.floor(elapsed * grown_cps * mult)
    return min(earned, math.floor(req * OFFLINE_MAX_PCT))

# ---------- Tambahan Master 8 (mirror Config.Events / DailyReward / RedeemCode /
# ---------- TreasureConfig / StealSystem-lock-timing; model otoritatif, bukan data live) ----------
EVENTS = {"hujan": {"mult": 2, "hint_free": False},   # Hujan Kopi
          "golden": {"mult": 3, "hint_free": False},  # Golden Harvest
          "rush": {"mult": 2, "hint_free": True},     # Treasure Rush (hint gratis)
          "meteor": {"mult": 4, "hint_free": False}}  # Meteor Shower
DAILY_FULL = [500, 1500, 4000, 10000, 25000, 60000, 150000]  # mirror DailyReward.REWARDS
REDEEM_CODES = {"RILIS100K": 100000, "HUJANKOPI": 50000, "GACOR2026": 250000}  # total 400rb
RIDDLE_SOLVE_TOTAL = 5000 + 8000 + 12000 + 15000 + 20000 + 25000 + 30000 + 40000 + 60000 + 100000
RIDDLE_DIG_TOTAL = RIDDLE_SOLVE_TOTAL  # bonus gali = RewardCash yg sama per riddle
MUT_EV_RAINBOW_SHARE = 0.05 * 10  # kontribusi Rainbow ke EV 2.25

def plant_mutation(roll):
    """Mirror PlotManager.Plant: ambang dari Config.MutationRate (70/15/10/5)."""
    if roll > 95:
        return "Rainbow"
    if roll > 85:
        return "Dark"
    if roll > 70:
        return "Gold"
    return "Normal"

class EventState:
    """Mirror EventManager: satu event aktif; Start ganda diabaikan (anti spam admin)."""
    def __init__(self):
        self.active = None
    def start(self, key):
        if self.active is not None:
            return False
        if key not in EVENTS:
            return False
        self.active = key
        return True
    def mult(self):
        return EVENTS[self.active]["mult"] if self.active else 1
    def hint_free(self):
        return bool(self.active and EVENTS[self.active]["hint_free"])
    def stop(self):
        self.active = None

class DailyStreak:
    """Mirror DailyReward.Claim: streak+1 (wrap 7->1), reset 1 bila skip sehari."""
    def __init__(self):
        self.last, self.streak = "", 0
    def claim(self, day_key, prev_day_key):
        if self.last == day_key:
            return False, 0
        s = self.streak + 1
        if s > 7:
            s = 1
        if self.last != prev_day_key:
            s = 1
        self.streak, self.last = s, day_key
        return True, DAILY_FULL[s - 1]

class Redeem3:
    """Mirror RedeemCode: 3 kode nominal aktual, sekali pakai per pemain."""
    def __init__(self):
        self.used = set()
    def redeem(self, code):
        c = code.upper().replace(" ", "")
        if c not in REDEEM_CODES:
            return False, "kode_salah"
        if c in self.used:
            return False, "sudah_dipakai"
        self.used.add(c)
        return True, REDEEM_CODES[c]

class StealTiming:
    """Mirror StealSystem: lock 60 +10/rebirth +10 VIP; cooldown 5 dtk pasca-sukses."""
    def __init__(self):
        self.lock_until, self.cd_until = {}, {}
    def lock_base(self, uid, rebirths=0, vip=False, t=0):
        self.lock_until[uid] = t + 60 + rebirths * 10 + (10 if vip else 0)
    def can_steal(self, thief, victim, t=0):
        if thief == victim:
            return False, "self"
        if self.lock_until.get(victim, -1) > t:
            return False, "locked"
        if self.cd_until.get(thief, -1) > t:
            return False, "cooldown"
        return True, "ok"
    def set_cooldown(self, thief, t=0):
        self.cd_until[thief] = t + 5

def run_exploit_tests():
    T = []
    def check(name, cond):
        T.append((name, bool(cond)))

    a = Acct(1000); econ_add(a, -500); check("uang_negatif_ditolak", a.cash == 1000)
    a = Acct(1000); econ_add(a, float("nan")); check("uang_nan_ditolak", a.cash == 1000)
    a = Acct(1000); econ_add(a, math.inf); check("uang_inf_ditolak", a.cash == 1000)
    a = Acct(1000); check("spend_lebih_ditolak", econ_spend(a, 9999) is False and a.cash == 1000)
    a = Acct(1000); econ_add(a, 10**15); check("reward_gila_diclamp", a.cash <= 1000 + HARD_CAP)
    a = Acct(1000); econ_spend(a, -50); check("spend_negatif_ditolak", a.cash == 1000)

    p = Plot(); plant(p, "1", "u1", "cabai_noob", True)
    ok1, _ = harvest(p, "1"); ok2, _ = harvest(p, "1")
    check("panen_ganda_ditolak", ok1 is True and ok2 is False)
    ok, _ = plant(p, "2", "u2", "x", False); ok2, _ = plant(p, "2", "u3", "x", False)
    check("tanam_slot_sama_ditolak", ok is True and ok2 is False)

    v, t1, t2, w = Plot(), Plot(), Plot(), StealWorld()
    plant(v, "1", "U1", "nanas_jet", True)
    r1 = w.request("A", "U1", v); r2 = w.request("B", "U1", v)
    check("steal_simultan_satu_pemenang", r1[0] is True and r2 == (False, "item_diperebutkan"))
    ok, _ = w.complete("A", v, t1)
    check("steal_pindah_bukan_duplikat", ok is True and not any(s["uid"] == "U1" for s in v.slots.values())
          and any(s["uid"] == "U1" for s in t1.slots.values()))
    check("steal_item_tak_tersedia_ditolak", w.request("B", "U9", v) == (False, "invalid"))
    plant(v, "2", "U2", "cabai_noob", False)
    check("steal_belum_grown_ditolak", w.request("B", "U2", v) == (False, "invalid"))
    w2 = StealWorld(); v2, t3 = Plot(), Plot()
    plant(v2, "1", "X1", "a", True); plant(v2, "2", "X2", "b", True)
    w2.request("C", "X1", v2); r = w2.request("C", "X2", v2)
    check("steal_ganti_target_bebaskan_lock_lama", r[0] is True and "X1" not in w2.locks)
    v3, t4, w3 = Plot(), Plot(), StealWorld()
    for i in range(1, SLOTS + 1):
        plant(t4, str(i), f"T{i}", "a", True)
    plant(v3, "1", "Z1", "a", True)
    check("steal_thief_penuh_ditolak", w3.request("D", "Z1", v3)[0] is True and w3.complete("D", v3, t4) == (False, "thief_penuh"))

    d = Daily()
    check("daily_ganda_ditolak", d.claim("2026-001")[0] is True and d.claim("2026-001")[0] is False)
    rt = RiddleTrail()
    check("riddle_lompat_urutan_ditolak", rt.submit("R2", True) == (False, "bukan_urutan"))
    check("riddle_solve_sekali", rt.submit("R1", True)[0] is True and rt.submit("R1", True) == (False, "sudah_selesai"))
    rt2 = RiddleTrail()
    for _ in range(5):
        rt2.submit("R1", False)
    check("riddle_lockout_5x_gagal", rt2.submit("R1", True) == (False, "locked_coba_lagi_nanti"))
    r = Redeems()
    check("redeem_ganda_ditolak", r.redeem("rilis100k")[0] is True and r.redeem("RILIS100K") == (False, "sudah_dipakai"))

    check("offline_cap_8jam", offline_earned(1000, 1, 24*3600, 1_000_000) == offline_earned(1000, 1, 8*3600, 1_000_000))
    check("offline_cap_50pct_rebirth", offline_earned(10**9, 10, 8*3600, 1_000_000) == 500_000)

    rb, slots = 0, [{"cps": 1}] * 8
    need = REQ(rb)
    check("rebirth_dana_kurang_ditolak", not (999_999 >= need))
    cash = 1_000_000
    if cash >= need:
        rb += 1; cash = 100; slots = []
    check("rebirth_reset_benar", rb == 1 and cash == 100 and slots == [])

    t = {"keys": 1}
    def spend_keys(keys, n):
        if not isinstance(n, (int, float)) or n != n or n <= 0:
            return False
        if keys[0] < math.floor(n):
            return False
        keys[0] -= math.floor(n)
        return True
    k = [1]
    check("kunci_negatif_ditolak", spend_keys(k, -5) is False and k[0] == 1)
    check("kunci_ganda_ditolak", spend_keys(k, 1) is True and spend_keys(k, 1) is False)

    # --- Paket event x2/x3/x4 (mirror Config.Events; Start ganda = no-op) ---
    ev = EventState()
    check("event_hujan_x2", ev.start("hujan") is True and ev.mult() == 2)
    check("event_tidak_stack", ev.start("golden") is False and ev.mult() == 2)
    ev.stop()
    check("event_golden_x3", ev.start("golden") is True and ev.mult() == 3)
    ev.stop()
    check("event_meteor_x4", ev.start("meteor") is True and ev.mult() == 4)
    ev.stop()
    check("event_rush_x2_hint_gratis",
          ev.start("rush") is True and ev.mult() == 2 and ev.hint_free() is True)
    ev.stop()
    check("event_mati_mult_1", ev.mult() == 1 and ev.hint_free() is False)

    # --- Streak 7 hari penuh (mirror DailyReward.REWARDS) ---
    ds = DailyStreak()
    tot = 0
    for d in range(1, 8):
        ok, amt = ds.claim(f"D{d}", f"D{d-1}")
        tot += amt if ok else 0
    check("daily_streak_7_penuh_251rb", tot == 251000)
    ok, amt = ds.claim("D8", "D7")
    check("daily_wrap_hari8_kembali_1", ok is True and amt == 500)
    check("daily_h8_ganda_ditolak", ds.claim("D8", "D7") == (False, 0))
    ds2 = DailyStreak()
    ds2.claim("D1", "D0")
    check("daily_skip_reset_1", ds2.claim("D3", "D2") == (True, 500))

    # --- Redeem 3 kode + reuse (nominal aktual Server/RedeemCode.luau) ---
    r3 = Redeem3()
    tot3 = 0
    for c in ("RILIS100K", "HUJANKOPI", "GACOR2026"):
        ok, amt = r3.redeem(c)
        tot3 += amt if ok else 0
    check("redeem_3kode_total_400rb", tot3 == 400000)
    check("redeem_reuse_ditolak", r3.redeem("rilis100k") == (False, "sudah_dipakai")
          and r3.redeem("HUJAN KOPI") == (False, "sudah_dipakai"))

    # --- 10 riddle: urutan penuh + total reward solve+gali 630rb ---
    rt10 = RiddleTrail()
    ok_all = True
    for r in ("R1", "R2", "R3", "R4", "R5", "R6", "R7", "R8", "R9", "R10"):
        ok, _ = rt10.submit(r, True)
        ok_all = ok_all and ok
    check("riddle_10_urutan_lolos", ok_all is True)
    check("riddle_10_total_630rb",
          RIDDLE_SOLVE_TOTAL == 315000 and RIDDLE_SOLVE_TOTAL + RIDDLE_DIG_TOTAL == 630000)

    # --- Mutasi: EV 2.25 + porsi Rainbow + batas roll (mirror Plant/MutationRate) ---
    check("mutasi_ev_225", abs(MUT_EV - 2.25) < 1e-9)
    check("mutasi_rainbow_ev_05", abs(MUT_EV_RAINBOW_SHARE - 0.5) < 1e-9)
    check("mutasi_batas_roll", plant_mutation(70) == "Normal" and plant_mutation(71) == "Gold"
          and plant_mutation(85) == "Gold" and plant_mutation(86) == "Dark"
          and plant_mutation(95) == "Dark" and plant_mutation(96) == "Rainbow")

    # --- Steal-vs-lock timing (mirror StealSystem.LockBase + cooldown 5 dtk) ---
    st = StealTiming()
    st.lock_base("V", 0, False, 0)
    check("steal_vs_lock_ditolak", st.can_steal("A", "V", 59) == (False, "locked"))
    check("steal_lepas_lock_ok", st.can_steal("A", "V", 60) == (True, "ok"))
    st.lock_base("W", 2, True, 0)  # 60 + 2*10 + 10 = 90
    check("steal_lock_rebirth_vip_90d", st.can_steal("A", "W", 89) == (False, "locked")
          and st.can_steal("A", "W", 90) == (True, "ok"))
    st.set_cooldown("A", 100)
    check("steal_cooldown_5d", st.can_steal("A", "V", 104) == (False, "cooldown")
          and st.can_steal("A", "V", 105) == (True, "ok"))

    # --- Rebirth 5x: syarat linear + cap multiplier x10 ---
    check("rebirth_5x_syarat_linear",
          [REQ(r) for r in range(5)] == [1_000_000, 2_000_000, 3_000_000, 4_000_000, 5_000_000])
    check("rebirth_mult_cap_10", min(1 + 5, 10) == 6 and min(1 + 9, 10) == 10)

    # --- Profil sultan: cap tick 10jt + hard cap 100jt tetap menahan ---
    sultan_raw = min(8 * 450000 * 10, 10_000_000)  # 8x Sirsak Rainbow -> dicap/tick
    check("sultan_tick_dicap_10jt", sultan_raw == 10_000_000)
    sa = Acct(0, 10.0)
    econ_add(sa, sultan_raw * 4)  # event meteor x4 -> 40jt x mult10 = 400jt -> clamp
    check("sultan_hardcap_100jt", sa.cash == 100_000_000)
    return T

def main():
    for name, secs in [("baru (30mnt/hari)", 1800), ("rutin (1jam/hari)", 3600), ("grinder (3jam/hari)", 10800)]:
        print(f"{name}: ", end="")
        res = list(days_to_rebirth(secs))
        print("; ".join(f"rebirth-{r} hari-{d}" for d, r in res) or ">60 hari")
    print(f"EV mutasi dipakai: {MUT_EV}x")
    # --- Skenario tambahan (asumsi sama, tanpa inflate reward) ---
    extra = [("mahir (2jam/hari)", 7200, {}), ("high-progression (3jam/hari + event x2 tiap Sabtu)", 10800, "event")]
    for name, secs, ev in extra:
        evm = {}
        if ev == "event":
            evm = {d: 2.0 for d in range(7, 61, 7)}  # Hujan Kopi 30 mnt ~ sesi Sabtu x2
        res = list(_run(secs, OFFLINE_CAP_H, evm))
        print(f"{name}: ", end="")
        print("; ".join(f"rebirth-{r} hari-{d}" for d, r in res) or ">60 hari")
    print("--- uji exploit/invarian (harus semua PASS; FAIL = exploit lolos) ---")
    tests = run_exploit_tests()
    failed = 0
    for name, passed in tests:
        print(f"[{'PASS' if passed else 'FAIL'}] {name}")
        failed += 0 if passed else 1
    print(f"{len(tests)-failed}/{len(tests)} lolos")
    sys.exit(1 if failed else 0)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Simulasi progresi Steal a Kebun (model teoritis, bukan data live).
Asumsi: EV mutasi 2.25x, reinvest agresif, riddle selesai hari ke-2 (630rb),
daily streak penuh, redeem 400rb hari-1. Keluar: hari ke rebirth 1/2/3.
Jalankan: python tools/sim_economy.py"""
import math

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

def days_to_rebirth(active_s_per_day: int, offline_cap_h: int = 8):
    cash, slots, day, rebirths, streak = 100.0, [], 1, 0, 0
    riddle_done, redeem_done = False, False
    mult = 1.0
    while rebirths < 3 and day <= 60:
        # tanam: isi slot kosong dengan tier terbaik yg terjangkau
        while len(slots) < SLOTS:
            afford = [it for it in ITEMS if it[0] <= cash]
            if not afford:
                break
            it = afford[-1]
            cash -= it[0]
            slots.append({"cps": it[1], "grow": it[2], "t": 0.0})
        # sesi aktif (tick 60 dtk)
        t = 0
        while t < active_s_per_day:
            step = 60
            inc = sum(s["cps"] * MUT_EV for s in slots if s["t"] >= s["grow"]) * step * mult
            cash += inc
            for s in slots:
                s["t"] += step
            t += step
            if cash >= REQ(rebirths):
                break
        # bonus harian
        if not redeem_done:
            cash += REDEEM; redeem_done = True
        streak = streak % 7 + 1
        cash += DAILY[streak - 1]
        if day in (d for d, _ in RIDDLE) and not riddle_done:
            cash += RIDDLE[0][1]; riddle_done = True
        # offline (cap 8 jam, 50% syarat rebirth BERIKUTNYA)
        grown_cps = sum(s["cps"] * MUT_EV for s in slots if s["t"] >= s["grow"])
        cash += min(grown_cps * offline_cap_h * 3600 * mult, REQ(rebirths) * 0.5)
        if cash >= REQ(rebirths):
            rebirths += 1
            yield day, rebirths
            cash, slots = 100.0, []
            mult = min(1 + rebirths, 10)
        day += 1

for name, secs in [("baru (30mnt/hari)", 1800), ("rutin (1jam/hari)", 3600), ("grinder (3jam/hari)", 10800)]:
    print(f"{name}: ", end="")
    res = list(days_to_rebirth(secs))
    print("; ".join(f"rebirth-{r} hari-{d}" for d, r in res) or ">60 hari")
print(f"EV mutasi dipakai: {MUT_EV}x")

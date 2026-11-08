#!/usr/bin/env python3
"""Audit UI: setiap teks UI harus punya ukuran font eksplisit (TextSize),
bukan TextScaled (tidak konsisten lintas layar). Portabel, satu ringkasan,
exit code benar (1 jika ada temuan).
Jalankan dari mana saja: python <repo>/tools/ui-audit.py"""
import pathlib
import re
import sys

BASE = pathlib.Path(__file__).resolve().parents[1]
SRC = BASE / "src" / "Client"  # hanya UI layar; Billboard 3D server dikecualikan (skala jarak)

kurang = []
scaled_left = []
for f in sorted(SRC.rglob("*.luau")):
    t = f.read_text(encoding="utf-8", errors="ignore")
    btns = len(re.findall(r'Instance\.new\("Text(Button|Label|Box)"', t))
    scaled = len(re.findall(r"\.TextScaled\s*=", t))
    sized = len(re.findall(r"\.TextSize\s*=", t))
    if btns and (scaled + sized) < btns:
        kurang.append(f"{f.relative_to(SRC)}: {btns} teks, hanya {scaled + sized} berukuran")
    if scaled:
        scaled_left.append(f"{f.relative_to(SRC)}: {scaled} TextScaled tersisa")

if kurang or scaled_left:
    for k in kurang:
        print("KURANG UKURAN:", k)
    for k in scaled_left:
        print("TEXTSCALED SISA:", k)
    print(f"HASIL: {len(kurang)} file kurang ukuran, {len(scaled_left)} file masih pakai TextScaled")
    sys.exit(1)
print(f"HASIL: OK - 0 TextScaled, semua teks UI berukuran eksplisit")

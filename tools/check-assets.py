#!/usr/bin/env python3
"""Cek AssetMap mana yang belum diisi ID. Jalankan: python tools/check-assets.py"""
import pathlib, re
base = pathlib.Path(__file__).resolve().parents[1]
f = base / "src" / "Shared" / "AssetMap.luau"
txt = f.read_text(encoding="utf-8")
# buang baris comment agar contoh di comment tidak kehitung
lines = [l for l in txt.splitlines() if not l.strip().startswith("--")]
txt = "\n".join(lines)
missing = re.findall(r'\["([^"]+)"\]\s*=\s*""', txt)
filled = re.findall(r'\["([^"]+)"\]\s*=\s*"rbxassetid://[^"]+"', txt)
print(f"Terisi: {len(filled)} | Kosong: {len(missing)}")
if missing:
    print("Belum upload:")
    for m in missing:
        print(f" - {m}")
else:
    print("Semua aset sudah ada ID. Siap publish.")

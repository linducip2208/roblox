#!/usr/bin/env python3
"""Tulis ulang 3 workflow API ComfyUI dari comfy_batch.py ke assets/workflows/*.json.
Jalankan sekali: python tools/save-workflows.py"""
import json, pathlib
import sys
sys.path.insert(0, r"D:\project laravel\roblox\tools")
from comfy_batch import workflow, NEG, CKPT

OUT = pathlib.Path(r"D:\project laravel\roblox\assets\workflows")
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "plant_icon.json").write_text(json.dumps(
    workflow("CONTOH: red chili chibi character, cute fruit mascot", NEG, 1024, 1024, 42), indent=1))
(OUT / "game_thumbnail.json").write_text(json.dumps(
    workflow("CONTOH: blocky avatars chasing giant golden watermelon, farm, red arrow", NEG, 1344, 768, 42), indent=1))
(OUT / "game_icon.json").write_text(json.dumps(
    workflow("CONTOH: golden coffee cup mascot, yellow background, game icon", NEG, 1024, 1024, 42), indent=1))
print("workflows tersimpan:", sorted(p.name for p in OUT.glob("*.json")))
print("checkpoint:", CKPT, "| catatan: ganti teks CONTOH dengan prompt final")

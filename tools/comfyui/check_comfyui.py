#!/usr/bin/env python3
"""Audit ComfyUI lokal: server, model, node, VRAM, direktori output.
Jalankan: python tools/comfyui/check_comfyui.py (dari mana saja)."""
import json
import pathlib
import sys
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from repo import BASE

COMFY = "http://127.0.0.1:8188"


def get(path: str):
    with urllib.request.urlopen(COMFY + path, timeout=30) as r:
        return json.load(r)


def main() -> int:
    try:
        stats = get("/system_stats")
    except Exception as e:
        print(f"COMFY DOWN: {e}")
        print("Jalankan D:\\ComfyUI manual (run_nvidia_gpu.bat) lalu ulangi.")
        return 1
    dev = stats["devices"][0]
    print(f"server: {stats['system']['comfyui_version']} | "
          f"gpu: {dev['name']} | vram_free_gb: {dev.get('vram_free', 0)/1e9:.2f}")
    import os
    models = os.listdir(r"D:\AI_Models\checkpoints")
    print("checkpoints:", ", ".join(m for m in models if m.endswith(".safetensors")))
    for d in ("vae", "loras", "upscale_models"):
        files = os.listdir(rf"D:\AI_Models\{d}")
        print(f"{d}:", ", ".join(files[:6]) or "-")
    nodes_dir = pathlib.Path(r"D:\ComfyUI\custom_nodes")
    nodes = sorted(p.name for p in nodes_dir.iterdir() if p.is_dir()) if nodes_dir.exists() else []
    print("custom_nodes:", ", ".join(nodes))
    need = {"CheckpointLoaderSimple", "CLIPTextEncode", "EmptyLatentImage",
            "KSampler", "VAEDecode", "SaveImage", "UpscaleModelLoader",
            "UpscaleImageUsingModel"}
    try:
        info = get("/object_info")
        have = set(info.keys())
        missing = need - have
        print("node inti:", "OK semua ada" if not missing else f"HILANG {sorted(missing)}")
    except Exception as e:
        print(f"object_info gagal: {e}")
    out = BASE / "assets" / "generated"
    n = sum(1 for _ in out.rglob("*.png")) if out.exists() else 0
    print(f"output generated/: {n} png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

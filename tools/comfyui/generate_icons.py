#!/usr/bin/env python3
"""Generate 8 ikon UI STEAL A KEBUN via ComfyUI API (SDXL Lightning 8-step).
Output: assets/generated/ui/<nama>.png + update manifest.
Jalankan: python tools/comfyui/generate_icons.py (~2-3 mnt)"""
import json
import pathlib
import random
import sys
import time
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from repo import BASE

COMFY = "http://127.0.0.1:8188"
CKPT = "sdxl_lightning_8step.safetensors"
STYLE = ("cute 3d cartoon game icon, glossy toy render, soft studio lighting, "
         "vibrant colors, centered, plain white background, no text, no watermark")
NEG = ("blurry, dark, horror, photorealistic, text, watermark, logo, "
       "deformed, extra limbs, cropped, lowres")

ICONS = {
    "ui-shovel": "small garden shovel tool with wooden handle",
    "ui-compass": "small golden pocket compass, top-down flat view, centered single object, isolated on pure white background, icon",
    "ui-chest": "small wooden treasure chest box with golden trim, centered single object, isolated on pure white background, icon",
    "ui-coin": "shiny gold coin with star emblem",
    "ui-key": "golden ancient key",
    "ui-lock": "golden padlock, locked",
    "ui-gift": "wrapped gift box with red ribbon",
    "ui-trophy": "golden trophy cup",
}


def api(path, data=None):
    req = urllib.request.Request(
        COMFY + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.load(r)


def workflow(prompt):
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CKPT}},
        "2": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": NEG, "clip": ["1", 1]}},
        "4": {"class_type": "EmptyLatentImage", "inputs": {"width": 512, "height": 512, "batch_size": 1}},
        "5": {"class_type": "KSampler", "inputs": {"seed": random.randint(0, 2**31 - 1),
               "steps": 8, "cfg": 1.5, "sampler_name": "euler", "scheduler": "sgm_uniform",
               "denoise": 1.0, "model": ["1", 0], "positive": ["2", 0],
               "negative": ["3", 0], "latent_image": ["4", 0]}},
        "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage", "inputs": {"filename_prefix": "kebun/tmp", "images": ["6", 0]}},
    }


def main():
    out = BASE / "assets" / "generated" / "ui"
    out.mkdir(parents=True, exist_ok=True)
    manifest_path = BASE / "assets" / "generated" / "manifest.json"
    manifest = json.load(open(manifest_path, encoding="utf-8"))
    done = 0
    for name, desc in ICONS.items():
        dest = out / (name + ".png")
        if dest.exists():
            print(f"lewati (sudah ada): {name}")
            done += 1
            continue
        t0 = time.time()
        q = api("/prompt", {"prompt": workflow(f"{desc}, {STYLE}")})
        pid = q["prompt_id"]
        while True:
            time.sleep(4)
            hist = api(f"/history/{pid}")
            if pid in hist:
                break
            if time.time() - t0 > 600:
                print(f"TIMEOUT {name}")
                break
        node = hist[pid]["outputs"]
        saved = None
        for _, o in node.items():
            for img in o.get("images", []):
                saved = img
        if not saved:
            print(f"GAGAL {name}")
            continue
        url = (f"{COMFY}/view?filename={saved['filename']}"
               f"&subfolder={saved.get('subfolder','')}&type={saved.get('type','output')}")
        urllib.request.urlretrieve(url, dest)
        manifest.append({"name": f"ui/{name}", "file": str(dest), "seed": None,
                         "size": [512, 512], "status": "done",
                         "usage": "UI icon (Inventory/Shop/Treasure)",
                         "validated": False, "roblox_status": "UPLOAD_PENDING",
                         "roblox_asset_id": ""})
        print(f"OK {name} ({time.time()-t0:.0f}s)")
        done += 1
    json.dump(manifest, open(manifest_path, "w", encoding="utf-8"), indent=1)
    print(f"SELESAI {done}/{len(ICONS)}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Batch generate Steal a Kebun assets via ComfyUI API (SDXL Lightning 8-step).
Output: assets/generated/<kategori>/*.png + manifest.json
Jalankan: python tools/comfy_batch.py  (lama: ~15-25 mnt, 26 gambar)
"""
import json, os, random, sys, time, urllib.request, urllib.error
from repo import BASE
import pathlib

COMFY = "http://127.0.0.1:8188"
OUT = pathlib.Path(str(BASE) + r"\assets\generated")
CKPT = "sdxl_lightning_8step.safetensors"

STYLE_ICON = ("bright stylized 3d cartoon toy render, soft studio lighting, vibrant colors, "
              "centered full body, plain white background, high quality, no text, no watermark, no logo")
NEG = ("blurry, dark, horror, photorealistic, realistic photo, text, watermark, logo, "
       "deformed, extra limbs, cropped, lowres, ugly")

JOBS = [
    ("game-icon/icon-512", "giant golden coffee cup mascot with happy face and tiny arms, two small chibi fruit friends cheering beside it, solid vivid yellow background, bold readable silhouette, mobile game icon", 1024, 1024),
    ("thumbnails/thumb-1", "roblox-like blocky avatar running away carrying giant glowing golden watermelon, other blocky avatars chasing, crowded colorful farm with garden plots, big red arrow pointing at watermelon, bright saturated, chaotic fun, wide composition, no text", 1344, 768),
    ("thumbnails/thumb-2", "three roblox-like blocky avatars pulling a giant red umbrella in cartoon coffee rain, splashes, dramatic clouds, vibrant, wide composition, no text", 1344, 768),
    ("thumbnails/thumb-3", "closeup glowing golden holographic palm fruit with rainbow particles and rays, dark spotlight background, legendary aura, premium game splash art, no text", 1344, 768),
]

PLANTS = [
    ("plants/cabai_noob", "red chili pepper chibi character crying funny face with tears, tiny arms"),
    ("plants/wortel_goyang", "orange carrot chibi character dancing, wearing cool black sunglasses"),
    ("plants/tomat_gendut", "fat round red tomato chibi character laughing happily"),
    ("plants/jagung_rave", "corn chibi character wearing dj headphones, neon party glow"),
    ("plants/terong_disco", "purple eggplant chibi character with disco mirror ball sparkles"),
    ("plants/semangka_mewing", "green watermelon chibi character with confident smirk face"),
    ("plants/pisang_sultan", "yellow banana chibi character wearing golden crown and red robe"),
    ("plants/durian_megar", "spiky durian fruit monster chibi, muscular, fierce but cute"),
    ("plants/anggur_roblox", "purple grape cluster chibi character wearing green hacker matrix glasses"),
    ("plants/mangga_ohio", "orange mango chibi character with silly wobbly face"),
    ("plants/apel_brainrot", "red apple chibi character with shark teeth, italian brainrot meme style"),
    ("plants/nanas_jet", "pineapple chibi character with small jet engines on sides, flying"),
    ("plants/kelapa_godzilla", "coconut chibi character as mini godzilla with atomic breath glow"),
    ("plants/melon_skibidi", "green melon chibi character popping out of a toilet, funny"),
    ("plants/stroberi_tung", "strawberry chibi character holding wooden stick, tung tung style"),
    ("plants/leci_tralala", "white lychee chibi character wearing blue shark sneakers"),
    ("plants/kiwi_bombardilo", "kiwi fruit chibi character as bomber plane with crocodile wings"),
    ("plants/sirsak_titan", "soursop fruit chibi character wearing titan armor"),
    ("plants/sawit_garut", "golden palm oil fruit chibi character, holographic rainbow glow, legendary"),
    ("plants/kopi_gacor", "brown coffee cup chibi character with golden phoenix wings and steam, mythic glow"),
    ("plants/kopi_hujan", "coffee cup chibi character holding tiny umbrella under coffee rain drops"),
    ("plants/payung_raksasa", "giant red umbrella fruit character in cartoon rain"),
]
for name, p in PLANTS:
    JOBS.append((name, f"{p}, {STYLE_ICON}", 1024, 1024))
# prepend style to icon/thumb jobs (mereka prompt scene, tambah style ringan)
JOBS[0] = (JOBS[0][0], JOBS[0][1] + ", " + STYLE_ICON, 1024, 1024)
for i in (1, 2, 3):
    n, p, w, h = JOBS[i]
    JOBS[i] = (n, p + ", bright stylized 3d cartoon, vibrant, high quality, no text, no watermark", w, h)


def api(path, data=None):
    req = urllib.request.Request(COMFY + path,
        data=json.dumps(data).encode() if data is not None else None,
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.load(r)


def workflow(prompt, neg, w, h, seed):
    return {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": CKPT}},
        "2": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": neg, "clip": ["1", 1]}},
        "4": {"class_type": "EmptyLatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}},
        "5": {"class_type": "KSampler", "inputs": {"seed": seed, "steps": 8, "cfg": 1.5,
               "sampler_name": "euler", "scheduler": "sgm_uniform", "denoise": 1.0,
               "model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0], "latent_image": ["4", 0]}},
        "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage", "inputs": {"filename_prefix": "kebun/tmp", "images": ["6", 0]}},
    }


def main():
    # validasi server + checkpoint
    stats = api("/system_stats")
    print("comfyui:", stats["system"]["comfyui_version"], "| vram_free:",
          stats["devices"][0].get("vram_free"))
    manifest = []
    for name, prompt, w, h in JOBS:
        seed = random.randint(0, 2**31 - 1)
        try:
            q = api("/prompt", {"prompt": workflow(prompt, NEG, w, h, seed)})
            pid = q["prompt_id"]
        except urllib.error.HTTPError as e:
            print(f"GAGAL queue {name}: HTTP {e.code} {e.read()[:300]}")
            manifest.append({"name": name, "status": "queue_failed"})
            continue
        # tunggu selesai
        t0 = time.time()
        while True:
            time.sleep(4)
            try:
                hist = api(f"/history/{pid}")
            except Exception as e:
                print(f"  {name}: history error {e}, retry..."); continue
            if pid in hist:
                break
            if time.time() - t0 > 600:
                print(f"  {name}: TIMEOUT"); break
        node = hist[pid]["outputs"]
        saved = None
        for nid, out in node.items():
            for img in out.get("images", []):
                saved = img  # ambil terakhir
        if not saved:
            print(f"GAGAL render {name}"); manifest.append({"name": name, "status": "render_failed"})
            continue
        # unduh
        url = f"{COMFY}/view?filename={saved['filename']}&subfolder={saved.get('subfolder','')}&type={saved.get('type','output')}"
        dest = OUT / (name + ".png")
        dest.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(url, dest)
        print(f"OK {name} ({time.time()-t0:.0f}s, {dest.stat().st_size//1024}KB)")
        manifest.append({"name": name, "file": str(dest), "seed": seed,
                         "size": [w, h], "status": "done",
                         "usage": "upload Roblox Images/Decal" if name.startswith("plants") else "upload Roblox (icon/thumbnail)"})
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1))
    done = sum(1 for m in manifest if m["status"] == "done")
    print(f"SELESAI {done}/{len(JOBS)}")


if __name__ == "__main__":
    sys.exit(main())

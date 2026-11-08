# ASSET INVENTORY

## A. Placeholder lokal — `assets/out/` (92 file, SUDAH ADA, prosedural PIL)
- 22 base kartun (tiap item beda shape/warna/aksesori) + 66 varian (-gold/-dark/-rainbow).
- icon-512.png + thumb-1/2/3.png (komposit + teks Impact).
- Status: LAYAK TEST, BELUM LAYAK PUBLIKASI. Boleh upload untuk verifikasi pipa Decal.

## B. Generasi ComfyUI — `assets/generated/` (IN PROGRESS via tools/comfy_batch.py)
| Kategori | File | Ukuran | Model | Status |
|---|---|---|---|---|
| game-icon | icon-512.png | 1024 | sdxl_lightning_8step, 8 step cfg 1.5 | queued |
| thumbnails | thumb-1/2/3.png | 1344x768 | sama | queued |
| plants | 22 file | 1024 | sama, white bg | queued |
- Manifest: `assets/generated/manifest.json` (seed + status per file). Batch 8 Nov 2026:
  **26/26 done + 8 ikon UI = 34/34**, validated 34/34 OK.
- Kualitas spot-check: icon kopi emas, kopi_hujan — gaya konsisten, layak upload.
- Setelah selesai: pilih terbaik → timpa nama di `assets/out/` ATAU upload langsung,
  isi `AssetMap`, `rojo build` ulang.
- Varian mutasi: TIDAK perlu generate 66 — pakai tint otomatis / img2img dari base.

## C. Mapping pemakaian
- Decal plot: `PlotVisuals` pakai `AssetMap[itemId-mutasi]` → fallback warna.
- Shop/HUD: teks dulu, ikon setelah AssetMap terisi (NEXT polish).
- Store listing: icon + 3 thumb (upload manual di dashboard, BUKAN via Rojo).

## D. Aturan lisensi
- Semua art: prosedural sendiri / ComfyUI model lokal. Tanpa karakter/logo pihak ketiga.
- Jangan upload art ber-watermark. Moderasi Roblox 10-60 mnt per gambar.

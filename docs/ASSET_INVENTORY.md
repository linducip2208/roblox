# ASSET INVENTORY

## A. Placeholder lokal — `assets/out/` (92 file, SUDAH ADA, prosedural PIL)
- 22 base kartun (tiap item beda shape/warna/aksesori) + 66 varian (-gold/-dark/-rainbow).
- icon-512.png + thumb-1/2/3.png (komposit + teks Impact).
- Status: LAYAK TEST, BELUM LAYAK PUBLIKASI. Boleh upload untuk verifikasi pipa Decal.

## B. Generasi ComfyUI — `assets/generated/` (SELESAI 34/34 via tools/comfy_batch.py)
| Kategori | File | Ukuran | Model | Status |
|---|---|---|---|---|
| game-icon | icon-512.png | 1024 | sdxl_lightning_8step, 8 step cfg 1.5 | done, UPLOAD_PENDING |
| thumbnails | thumb-1/2/3.png | 1344x768 | sama | done, UPLOAD_PENDING |
| plants | 22 file | 1024, full-bleed | sama | done, UPLOAD_PENDING |
| ui icons | 8 file | 512 | sama | done, UPLOAD_PENDING |
- Manifest: `assets/generated/manifest.json` (34 entri, seed + status per file). Validasi
  resmi `python tools/comfyui/validate_assets.py` → **34/34 OK, manifest==disk 34/34**
  (9 Nov 2026). Semua `roblox_status=UPLOAD_PENDING`, `roblox_asset_id=""` — belum upload.
- Kualitas spot-check: icon kopi emas, kopi_hujan — gaya konsisten, layak upload.
- Setelah selesai: pilih terbaik → timpa nama di `assets/out/` ATAU upload langsung,
  isi `AssetMap`, `rojo build` ulang.
- Varian mutasi: TIDAK perlu generate 66 — pakai tint otomatis / img2img dari base.
- CATATAN 9 Nov 2026: plants hasil ComfyUI full-bleed (sudut tidak putih, mode RGB tanpa
  alpha) — Decal di Part bola tetap tampil penuh, bukan sprite potong-putih. Bukan blocker.

## E. Klasifikasi prioritas upload (owner)
- P0 (blocker rilis, wajah game): `game-icon/icon-512.png` + 3 thumb → upload via dashboard
  (Game Settings → Icon/Thumbnails), BUKAN via AssetMap. Estimasi ±15 mnt + moderasi.
- P1 (blocker gameplay visual): 22 plants → `Development Items → Images`, satu per satu,
  isi 22 kunci base di `src/Shared/AssetMap.luau`. Estimasi ±45–60 mnt + moderasi 10–60 mnt/gambar.
- P2 (polish, opsional): 8 ikon UI → upload bila P0+P1 lolos; game tetap jalan tanpa ini
  (fallback teks, `UiIcons.Attach` return false). Estimasi ±20 mnt.
- DITOLAK: 66 varian mutasi + 92 file `assets/out/` (placeholder PIL) — JANGAN upload publik.
  Mutasi dirender via tint kode; client fallback ke base bila ID varian kosong
  (`PlotVisuals.luau:81`).

## F. Langkah owner (urutan)
1. Buka Creator Dashboard → pilih experience → Development Items → Images.
2. Upload P0 (4 file) → set sebagai icon/thumbnail di Game Settings.
3. Upload P1 (22 file, nama = kunci AssetMap) → tunggu moderasi lolos per file.
4. Salin tiap `rbxassetid://...` ke kunci yang cocok di `src/Shared/AssetMap.luau`
   (JANGAN isi ID karangan). Cek: `python tools/check-assets.py`.
5. `rojo build` ulang → Play test: Decal muncul di bola crop, ikon muncul di tombol.
6. P2 bila sempat; varian mutasi HANYA setelah 22 base lolos.

## C. Mapping pemakaian
- Decal plot: `PlotVisuals` pakai `AssetMap[itemId-mutasi]` → fallback warna.
- Shop/HUD: teks dulu, ikon setelah AssetMap terisi (NEXT polish).
- Store listing: icon + 3 thumb (upload manual di dashboard, BUKAN via Rojo).

## D. Aturan lisensi
- Semua art: prosedural sendiri / ComfyUI model lokal. Tanpa karakter/logo pihak ketiga.
- Jangan upload art ber-watermark. Moderasi Roblox 10-60 mnt per gambar.

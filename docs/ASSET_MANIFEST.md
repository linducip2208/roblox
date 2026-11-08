# ASSET MANIFEST — status unduh-ke-Roblox (angka = file lokal, BUKAN klaim upload)

Sumber kebenaran file: `assets/generated/manifest.json` (34 entri, cocok disk 34/34,
tervalidasi PIL 34/34 OK). Kolom Asset ID diisi MANUAL dari Creator Dashboard.

Aturan: `roblox_status` hanya `UPLOAD_PENDING` sampai ID terisi + moderasi lolos.
Dilarang menulis `UPLOADED` tanpa Asset ID valid. Lihat rincian per file + kolom ID di
`docs/ROBLOX_ASSET_UPLOAD.md`.

## Ringkasan
| Kategori | Jumlah | Ukuran | Model | Status |
|---|---|---|---|---|
| game-icon | 1 | 1024 | sdxl_lightning_8step 8step cfg1.5 | GENERATED, UPLOAD_PENDING |
| thumbnails | 3 | 1344x768 | sama | GENERATED, UPLOAD_PENDING |
| plants | 22 | 1024, bg putih | sama | GENERATED, UPLOAD_PENDING |
| ui icons | 8 | 512, bg putih | sama | GENERATED, UPLOAD_PENDING |
| PIL placeholder (`assets/out/`) | 92+4 | 512/1080p | prosedural | TEST SAJA, JANGAN upload publik |

## Mapping pemakaian (ringkas; detail di ROBLOX_ASSET_UPLOAD.md)
- icon/thumb → halaman store (manual dashboard, bukan via Rojo).
- plants → `PlotVisuals` Decal via `AssetMap[itemId]` (+ varian `-gold/-dark/-rainbow`).
- ui-* → `UiIcons.Attach` di Shop/Inventory/Treasure (fallback teks bila ID kosong).
- Mutasi/varian tambahan: pakai tint kode + img2img bila perlu, bukan 92 upload.

## Verifikasi terakhir
`python tools/comfyui/validate_assets.py` → 34/34 OK, manifest==disk.

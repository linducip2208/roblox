# ASSET LIST — Steal a Kebun (total 34 file TERGENERASI di `assets/generated/`)

Hasil ComfyUI final ada di `assets/generated/` (34 file, manifest cocok 34/34 —
status 9 Nov 2026). `assets/out/` hanya berisi 92 placeholder PIL (JANGAN upload).

## 1. WAJIB (publish blocker)
| # | File | Ukuran | Dipakai | Prompt base |
|---|------|--------|---------|-------------|
| 1 | icon-512.png | 512x512 | Game icon | maskot kopi_gacor tengah, bg kuning solid, no text |
| 2 | thumb-1.png | 1920x1080 | Thumbnail A | avatar kaget bawa semangka emas raksasa + teks CURI!!! |
| 3 | thumb-2.png | 1920x1080 | Thumbnail B | 3 avatar tarik-tarikan payung raksasa, panah merah |
| 4 | thumb-3.png | 1920x1080 | Thumbnail C | closeup Secret sawit emas glowing + hujan kopi |

## 2. ITEM (22 Decal 512x512, white bg, centered)
- common: cabai_noob, wortel_goyang, tomat_gendut
- uncommon: jagung_rave, terong_disco, semangka_mewing
- rare: pisang_sultan, durian_megar, anggur_roblox
- epic: mangga_ohio, apel_brainrot, nanas_jet
- legendary: kelapa_godzilla, melon_skibidi, stroberi_tung
- mythic: leci_tralala, kiwi_bombardilo, sirsak_titan
- secret: sawit_garut, kopi_gacor (tambah rainbow particle + holographic)
- event: kopi_hujan, payung_raksasa (tambah rain + payung)

Semua: `chibi fruit character, big glossy eyes, tiny arms, studio lighting, white background, centered, game icon, no text, no watermark`

## 3. UI (8 ikon aktual di `assets/generated/`, gantikan daftar lama di bawah)
| File aktual | Ukuran | Dipakai |
|-------------|--------|---------|
| ui-shovel/ui-compass/ui-chest/ui-coin/ui-key/ui-lock/ui-gift/ui-trophy | 512x512 | Ikon UI + fallback teks |
Rencana badge lama di bawah ini SUPERSEDED (belum digenerate, bukan blocker beta):
| File | Ukuran | Dipakai |
|------|--------|---------|
| badge-rebirth.png | 512x512 | Badge rebirth 1 |
| badge-sultan.png | 512x512 | Badge 10 rebirth |
| btn-lock.png | 256x256 | Tombol kunci |
| bg-shop.png | 1024x1024 tile | Bg shop coklat kayu |

## Workflow
1. ComfyUI txt2img 1024 (30 steps, CFG 6.5) -> upscale 2x -> downscale ke ukuran di atas
2. Removebg untuk item (kecuali icon/thumb)
3. Upload: Create -> Images -> tunggu moderasi -> copy Asset ID ke `AssetMap.luau` (dibuat otomatis di bawah)
4. Test di Studio dengan lighting default, jangan gelap

Status: [x] 34/34 tergenerate di `assets/generated/` (UPLOAD_PENDING, tunggu moderasi owner) — centang lama "[ ] belum generate" usang per 9 Nov 2026.

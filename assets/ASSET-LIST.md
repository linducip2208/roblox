# ASSET LIST — Steal a Kebun (total 34 file)

Hasil ComfyUI -> taruh di `assets/out/` dengan nama persis, lalu upload ke Roblox.

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

## 3. UI + BADGE
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

Status: [ ] belum generate — ganti jadi [x] satu per satu.

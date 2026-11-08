# ROBLOX ASSET UPLOAD — daftar manual (JANGAN isi ID palsu)

Cara: Roblox Create Dashboard → Development Items → Images/Decals → upload file
lokal → tunggu moderasi (10-60 mnt) → salin `rbxassetid://...` ke
`src/Shared/AssetMap.luau` → `rojo build` ulang → Play test Decal muncul.

## A. Ikon + thumbnail (prioritas 1 — wajah game)
| File lokal | Kunci AssetMap | Dipakai di | Status | Asset ID |
|---|---|---|---|---|
| assets/generated/game-icon/icon-512.png | icon | Game icon (dashboard) | UPLOAD_PENDING | |
| assets/generated/thumbnails/thumb-1.png | thumb_a atau thumb-1 | Thumbnail A (dashboard) | UPLOAD_PENDING | |
| assets/generated/thumbnails/thumb-2.png | thumb_b atau thumb-2 | Thumbnail B | UPLOAD_PENDING | |
| assets/generated/thumbnails/thumb-3.png | thumb_c atau thumb-3 | Thumbnail C | UPLOAD_PENDING | |

## B. Tanaman 22 base (prioritas 2 — Decal plot via PlotVisuals)
| File lokal | Kunci AssetMap | Status | Asset ID |
|---|---|---|---|
| assets/generated/plants/cabai_noob.png | cabai_noob | UPLOAD_PENDING | |
| assets/generated/plants/wortel_goyang.png | wortel_goyang | UPLOAD_PENDING | |
| assets/generated/plants/tomat_gendut.png | tomat_gendut | UPLOAD_PENDING | |
| assets/generated/plants/jagung_rave.png | jagung_rave | UPLOAD_PENDING | |
| assets/generated/plants/terong_disco.png | terong_disco | UPLOAD_PENDING | |
| assets/generated/plants/semangka_mewing.png | semangka_mewing | UPLOAD_PENDING | |
| assets/generated/plants/pisang_sultan.png | pisang_sultan | UPLOAD_PENDING | |
| assets/generated/plants/durian_megar.png | durian_megar | UPLOAD_PENDING | |
| assets/generated/plants/anggur_roblox.png | anggur_roblox | UPLOAD_PENDING | |
| assets/generated/plants/mangga_ohio.png | mangga_ohio | UPLOAD_PENDING | |
| assets/generated/plants/apel_brainrot.png | apel_brainrot | UPLOAD_PENDING | |
| assets/generated/plants/nanas_jet.png | nanas_jet | UPLOAD_PENDING | |
| assets/generated/plants/kelapa_godzilla.png | kelapa_godzilla | UPLOAD_PENDING | |
| assets/generated/plants/melon_skibidi.png | melon_skibidi | UPLOAD_PENDING | |
| assets/generated/plants/stroberi_tung.png | stroberi_tung | UPLOAD_PENDING | |
| assets/generated/plants/leci_tralala.png | leci_tralala | UPLOAD_PENDING | |
| assets/generated/plants/kiwi_bombardilo.png | kiwi_bombardilo | UPLOAD_PENDING | |
| assets/generated/plants/sirsak_titan.png | sirsak_titan | UPLOAD_PENDING | |
| assets/generated/plants/sawit_garut.png | sawit_garut | UPLOAD_PENDING | |
| assets/generated/plants/kopi_gacor.png | kopi_gacor | UPLOAD_PENDING | |
| assets/generated/plants/kopi_hujan.png | kopi_hujan | UPLOAD_PENDING | |
| assets/generated/plants/payung_raksasa.png | payung_raksasa | UPLOAD_PENDING | |

## C. Ikon UI 8 file (prioritas 3 — ImageLabel via UiIcons, fallback teks)
| File lokal | Kunci AssetMap | Dipakai di | Status | Asset ID |
|---|---|---|---|---|
| assets/generated/ui/ui-shovel.png | ui-shovel | TreasureUI toolBtn, Inventory baris alat | UPLOAD_PENDING | |
| assets/generated/ui/ui-compass.png | ui-compass | TreasureUI compassBtn | UPLOAD_PENDING | |
| assets/generated/ui/ui-chest.png | ui-chest | TreasureUI digBtn, Inventory baris harta | UPLOAD_PENDING | |
| assets/generated/ui/ui-coin.png | ui-coin | Inventory baris uang | UPLOAD_PENDING | |
| assets/generated/ui/ui-key.png | ui-key | TreasureUI hintBtn | UPLOAD_PENDING | |
| assets/generated/ui/ui-lock.png | ui-lock | ShopUI lockBtn | UPLOAD_PENDING | |
| assets/generated/ui/ui-gift.png | ui-gift | ShopUI dailyBtn | UPLOAD_PENDING | |
| assets/generated/ui/ui-trophy.png | ui-trophy | ShopUI rbBtn | UPLOAD_PENDING | |

## D. Varian mutasi (opsional — otomatis dari PIL, bukan ComfyUI)
66 file `assets/out/*-gold/-dark/-rainbow.png`. Upload HANYA setelah 22 base lolos
(client otomatis pakai varian bila ID-nya ada, fallback ke base).

## Aturan
- Kolom Asset ID HANYA diisi dari dashboard Roblox, tidak pernah dikarang.
- Sebelum SEMUA prioritas 1+2 terisi, status rilis = BLOCKED (SCORECARD #28, #35).
- File `assets/out/*.png` (PIL placeholder) JANGAN diupload untuk publikasi.

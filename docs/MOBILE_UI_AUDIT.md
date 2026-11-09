# MOBILE UI AUDIT — Steal a Kebun (9 Nov 2026, Agen 5)

Metode: audit SUMBER statis (Rojo/Luau) tanpa Studio tanpa screenshot.
Semua status perangkat = NOT TESTED (jujur: tanpa HP/tablet fisik & Studio,
tidak ada klaim visual terverifikasi). Remote/logika server tidak diubah.

## Perubahan sesi ini (file + perbaikan)

- `src/Shared/UiTheme.luau`: tambah `Status` (Error/Ok/Info memetakan palet
  resmi, tanpa warna baru), `ViewportWidth/Height()` (fallback aman server),
  `FitPanel()` (jepit panel offset ke viewport, min 240x200), `MakeScrollable()`
  (scroll vertikal tipis warna `Dim`), `StyleStatus()` (error merah / sukses
  hijau via tema). Palet & kontrak lain tidak berubah.
- `src/Client/Hud.client.luau`: cash/info dapat `UISizeConstraint` (180..300)
  + rata kiri + padding; nav jadi anchor kanan-bawah `(1,-12,1,-12)` dengan
  constraint (216..300) dan `fitHud()` — tombol nav menyusut merata
  `(navW-12)/3` di 320px (tiap ~68px lebar, tetap 44px tinggi); pulse
  Tween relatif ke ukuran aktif (tidak reset ke 300px keras); dengar
  `ViewportSize` (portrait/landscape).
- `src/Client/ShopUI.client.luau`: frame anchor `(1,0)` pos `(1,-16,0,20)` +
  `FitPanel(340,420,32,120)` + listener viewport; toggle anchor `(1,0)` agar
  tak off-screen; scroll via `MakeScrollable`. Posisi lama `(1,-360,0,20)`
  jebol 40px di 320px — diperbaiki (kini lebar = min(340, vw-32) = 288).
- `src/Client/TreasureUI.client.luau`: frame anchor `(0,0.5)` pos `(0,16,0.5,0)`
  (ganti offset keras `-230`) + `FitPanel(340,430,32,120)` + listener; tombol
  pilihan `TextWrapped=true`, `TextSize` 17->15 anti-truncate; sukses/gagal
  jawab & gali kini warna status via `StyleStatus` (kode error server tetap).
- `src/Client/InventoryUI.client.luau`: frame anchor `(1,0.5)` pos
  `(1,-16,0.5,0)` + `FitProfile()` + listener; toggle anchor `(1,0.5)`;
  HAPUS duplikat `UiTheme.Title` ganda + `UiTheme.Button(toggleBtn)` tanpa
  warna yang menimpa gaya toggle jadi Primary; scroll via `MakeScrollable`.
- `src/Client/Tutorial.client.luau`: tambah `UISizeConstraint` (240x60 ..
  560x200) + `AutomaticSize.Y` + padding 10 (teks wrap 3 langkah tak kepotong);
  posisi bawah `-72` agar ada gap 12px di atas nav (nav atas di `-60`).
- `src/Client/StealPrompt.client.luau`, `Sound.client.luau`: tidak diubah
  (tanpa GUI / hanya ProximityPrompt + beep bawaan; tidak ada masalah layout).
- `src/Shared/UiPanels.luau`, `UiIcons.luau`: tidak diubah (registry tetap
  eksklusif shop/treasure/profile; ikon tetap bersyarat AssetMap).

Tidak ada panel/fitur baru; tidak ada `Register` baru (registry tetap persis
`profile, shop, treasure`); tidak ada perubahan RemoteEvent/Function/payload.

## Hasil per layar (kode) — semua viewport: analisis kode / NOT TESTED perangkat

| Layar | 320x568 | 375x667 | 390x844 | 430x932 | Tablet P/L | Desktop 1366/1920 |
|---|---|---|---|---|---|---|
| HUD cash/info+nav | muat (288 top, nav 296->68px/btn, 44 tinggi) / NOT TESTED | muat / NOT TESTED | muat / NOT TESTED | muat / NOT TESTED | muat / NOT TESTED | 300px tetap / NOT TESTED |
| Shop+Lock/Rebirth/Daily/Redeem | 288 lebar, tinggi<=448 scroll / NOT TESTED | muat scroll / NOT TESTED | muat / NOT TESTED | muat / NOT TESTED | muat / NOT TESTED | 340x420 / NOT TESTED |
| Treasure (riddle/hint/kompas/gali/tool) | 288 lebar scroll / NOT TESTED | muat / NOT TESTED | muat / NOT TESTED | muat / NOT TESTED | muat / NOT TESTED | 340x430 / NOT TESTED |
| Profil (stat/gamepass/mute) | 288 lebar scroll / NOT TESTED | muat / NOT TESTED | muat / NOT TESTED | muat / NOT TESTED | muat / NOT TESTED | 300x380 / NOT TESTED |
| Tutorial | 90%+wrap+autosize, gap nav / NOT TESTED | sama / NOT TESTED | sama / NOT TESTED | sama / NOT TESTED | max 560 / NOT TESTED | max 560 / NOT TESTED |
| Notifikasi (infoLabel/hud tick, steal_ok/stolen/fail, treasure_found, welcome/offline) | truncate 1 baris / NOT TESTED | sama | sama | sama | sama | sama |
| Dialog konfirmasi | tidak ada dialog modal custom (aksi via tombol panel + prompt beli Roblox bawaan) — N/A | — | — | — | — | — |
| Loading/empty/error | Shop `Stok: ...`, Treasure `Memuat...`/`10 selesai`, Profil `...`/`segera hadir`, tombol `❌/✅` + status warna; inline, tanpa modal / NOT TESTED | — | — | — | — | — |
| Navigasi | nav 3 tombol + toggle 44px per panel, eksklusif via registry / NOT TESTED | — | — | — | — | — |

## Sisa risiko (jujur)

1. Nol uji perangkat/Studio: overlap aktual, notch/safe-area, keterbacaan 5",
   keyboard menutupi redeemBox, performa scroll — semua NOT TESTED.
2. Panel penuh di 320px masih menutupi ~90% lebar saat terbuka; mitigasi =
   default terlipat <700px + toggle 1 ketuk (disengaja, bukan bug).
3. `TextTruncate` berarti teks panjang terpotong rapi (bukan bocor) di layar
   kecil — perlu cek visual owner.
4. Hover `UiTheme.Hover` no-op di sentuh (aman); tidak ada efek tekan khusus
   mobile.

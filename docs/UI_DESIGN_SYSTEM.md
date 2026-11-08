# UI DESIGN SYSTEM — Steal a Kebun (satu-satunya acuan visual)

## Palet resmi (WAJIB; abu-abu terang dilarang sebagai desain utama)
| Token | Hex | Pakai |
|---|---|---|
| Primary | #2878F0 | tombol aksi utama, beli, gali |
| Secondary | #25B978 | konfirmasi, daily, sukses |
| Gold | #FFC83D | judul, rebirth, hadiah |
| Background | #17243B | (cadangan) |
| Panel | #223653 | semua panel |
| Common | #7F91A8 | item common |
| Uncommon | #27B978 | item uncommon |
| Rare | #348BFA | item rare |
| Epic | #A45BEB | item epic |
| Legendary | #FFB52E | item legendary |
| Mythic | #F05269 | item mythic |
| Event | #19B8B0 | item event |
| White | #FFFFFF | teks |

## Komponen (`src/Shared/UiTheme.luau` — JANGAN hardcode warna di file UI)
- `DecoratePanel(f)`: bg Panel, transparansi 0.05, UICorner 8, UIStroke 1px, UIPadding 6.
- `Button(b, color?)`: bg Primary default, teks putih GothamBold, corner 8, hover lighten.
- `Title(l)`: Gold GothamBold. `Label(l)`: putih Gotham.
- `RarityColor(r)`: warna kartu tombol shop per rarity.
- `Hover(b)`: tween 0.12 dtk (client only, no-op aman di server).
- Ikon (`UiIcons.Attach`): ImageLabel 28px, HANYA jika AssetMap punya ID (tanpa ID = tanpa kotak rusak).

## Tipografi (anti TextScaled berlebihan)
- Judul panel: GothamBold 20. Tombol aksi: GothamBold 17-18. Label kecil: Gotham 14-15.
- Selalu `TextTruncate = AtEnd` (+ `TextWrapped` untuk teks panjang). Tidak ada teks terpotong diam-diam.

## Layout & layer
- `UiPanels` (`src/Shared/UiPanels.luau`): satu-satunya pengatur visible. Panel daftar
  sekali (`shop`, `treasure` default tutup, `profile`); HUD + tombol internal memanggil
  `Toggle/SetVisible` yang sama. Tidak ada GUI lama yang mengatur sendiri.
- HUD: cash 0,16 + income baris 2 + chip lock/multiplier + tombol nav (Shop/Harta/Profil).
- Toggle lipat 44x44 di tiap panel (X = buka, huruf = tutup) agar layar lega di HP.
- ScrollingFrame + AutomaticCanvasSize untuk daftar panjang (Shop, Treasure, Inventory).

## Status yang harus ada
- Shop: stok angka + HABIS + countdown restock; gagal beli = alasan ("miskin"/"HABIS").
- Treasure: loading ("Memuat...") vs selesai (bedakan dari gagal load), hint, kompas, hasil gali.
- Inventory: "segera hadir" untuk produk tanpa ID (tidak ada tombol mati).
- Tutorial: auto-hilang setelah cash >500; notifikasi steal/offline/event via HUD.

## Yang BELUM bisa diverifikasi tanpa Studio
Tampilan antar-aspek rasio, touch target di device, overlap di layar kecil, animasi terasa.
Status: PARTIAL. Uji di HP + tablet sebelum publik.

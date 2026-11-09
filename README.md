# Steal a Kebun — Simulator + Steal PvP (BETA, belum publikasi)

Game Roblox: simulator idle tanam-panen (ala Grow a Garden) + steal PvP antar-pemain
(ala Steal a Brainrot). Server 8 pemain, update konten mingguan Sabtu (event Hujan Kopi).

Status: **31 modul Luau, 0 TODO, Selene 0 error / 0 warning, StyLua bersih,
`rojo build` sukses.**
`python tools/verify.py` (9 Nov 2026, dijalankan aktual):
**FINAL: 44 PASS, 0 FAIL, 2 BLOCKED, 6 NOT TESTED**
(BLOCKED = `product-ids`, `admin-configured` — tindakan owner di dashboard/Config;
NOT TESTED = 6 uji yang hanya bisa jalan di Studio/produksi, lihat Testing.)

Belum production-tested: tidak ada klaim "rilis resmi", "teruji produksi", atau
"lolos moderasi" di dokumen ini. Semua checklist manusia/Studio masih terbuka.

## Fitur

- Tanam 22 item (common s.d. secret + 2 event), tumbuh 30 dtk–75 mnt, panen idle.
- Offline earning max 8 jam, dibatasi max 50% syarat rebirth (anti kaya instan).
- Mutasi tiap tanam: Normal 70% / Gold 15% / Dark 10% / Rainbow 5% (multiplier s.d. 10x).
- Steal PvP: tahan channel 3 dtk dalam 15 stud, item lock 60 dtk (+10/rebirth, +10 VIP),
  cooldown 5 dtk, TradePlaza = zona aman, thief penuh = steal ditolak sebelum channel.
- Rebirth 1 jt (skala linear x jumlah rebirth) = reset + multiplier +1x (max 10x).
- Treasure hunt 10 riddle multi-spot + kunci, sekop, kompas; jawaban hanya di server
  (`TreasureAnswers`, tidak ada di client).
- Event katalog 4 (hujan/golden/rush/meteor), auto Sabtu 19:00 WIB, trigger admin `;event`.
- Daily streak 7 hari (500 → 150 rb), kode redeem (`RILIS100K`, `HUJANKOPI`, `GACOR2026`).
- Monetisasi siap-kabel (nonaktif sampai owner isi ID): 2 GamePass + 2 DevProduct.
- Save fail-closed: session lock atomik (MemoryStore) + envelope versi + verifikasi
  lock sebelum commit + autosave 120 dtk + BindToClose paralel. Tanpa lock/load
  sukses: pemain tidak main / tidak ada save (data lama tidak pernah ditimpa default).
- UI: tema tunggal (UiTheme), panel eksklusif (UiPanels), ikon + fallback teks.

## Requirement

- Windows, drive D: (repo di `D:\project laravel\roblox`).
- Python 3 (untuk `tools/verify.py`).
- Roblox Studio (install ke D:, lihat Setup).
- Biner lokal di `tools/`: `rojo/rojo.exe`, `selene/selene.exe`, `stylua/stylua.exe`.
- PowerShell (jangan pakai `&&` ala bash; pakai `;`).

## Setup (Drive D, Rojo serve, plugin Studio)

1. Install Roblox Studio ke D: (jalankan sebagai Administrator):
   `PowerShell -ExecutionPolicy Bypass -File tools/install-studio-D.ps1`
2. Serve dari folder repo:
   `tools/rojo/rojo.exe serve` (atau `rojo serve` jika sudah di PATH).
3. Di Studio: install plugin Rojo → Connect `localhost:34872` → project tersinkron.
4. Main dengan 8 klien: tab Test → Clients and Servers → 8 Players → Start.
   Atau tanpa serve: buka `game.rbxlx` langsung (hasil build, double-click).

## Build

```powershell
tools/rojo/rojo.exe build default.project.json -o game.rbxlx
```

Hasil: satu file `game.rbxlx` (map dibangun runtime oleh MapBuilder, tidak ada
folder `src/World/` — disengaja). Buka file itu di Studio untuk publish/test.

## Instruksi Studio (wajib sebelum beta publik)

1. Buka `game.rbxlx` di Studio.
2. Game Settings → Security → aktifkan **Studio Access to API Services**
   (syarat uji DataStore/MemoryStore; tanpa ini join ditolak secara aman by design,
   dan mode EPHEMERAL hanya menyimpan progres di memori sesi itu saja).
3. Play test ikut `docs/QA.md` (fungsional + percobaan bobol + monetisasi + aset).
4. Aset: upload manual via dashboard Create → Development Items → Images/Decals,
   tunggu moderasi 10–60 mnt, salin `rbxassetid://...` ke `src/Shared/AssetMap.luau`,
   rebuild, pastikan Decal muncul di plot (lihat `docs/ROBLOX_ASSET_UPLOAD.md`).
5. Publish: File → Publish to Roblox As → nama `Steal a Kebun [BETA]`;
   Genre Simulation, 8 pemain, PC + Mobile; icon + thumbnail via dashboard
   (bukan via Rojo). Detail: `docs/ROBLOX_PUBLISHING.md`.

## Testing

Dari folder repo, tanpa Studio (gate mesin — harus hijau):

```powershell
python tools/verify.py
tools/selene/selene.exe src
tools/stylua/stylua.exe --check src
tools/rojo/rojo.exe build default.project.json -o game.rbxlx
```

Hasil aktual 9 Nov 2026 pada status commit bersih: verify **44 PASS / 0 FAIL /
2 BLOCKED / 6 NOT TESTED**; Selene 0/0; StyLua bersih; build sukses.
Catatan: saat dokumen ini ditulis, agen lain sedang mengedit `src/` (uncommitted)
sehingga run verify berikutnya sempat menunjukkan FAIL selene/stylua sementara —
itu WIP mereka, bukan regresi repo. Acuan angka di sini = run pada kondisi bersih.

Yang BUTUH Studio/produksi (tidak bisa dicek mesin — gate manusia/owner):

- `studio-8player`: Play test 8 klien (`docs/QA.md` fungsional + security).
- `studio-datastore-live`: experience terpisah + API access (save/load sungguhan).
- `studio-monetization`: produk asli + sandbox purchase.
- `studio-visual-device`: HP/tablet fisik + screenshot (overlap/keterbacaan).
- `studio-multiserver`: 2 server untuk uji session lock.
- `studio-shutdown`: uji BindToClose sungguhan.

## Konfigurasi (owner — 4 ID produk + AdminUserIds)

File: `src/Shared/Config.luau`. Saat ini SEMUA masih 0/kosong = monetisasi dan
perintah admin **nonaktif by design** (tidak error, tidak bisa dibeli/dipakai).

| Field | Harga rencana | Status |
|---|---|---|
| `Gamepasses.DoubleMoney` | 299 R$ | 0 — isi ID GamePass dari dashboard |
| `Gamepasses.VIP` | 375 R$ | 0 — isi ID GamePass dari dashboard |
| `Products.LuckBoost15m` | 99 R$ | 0 — isi ID DevProduct dari dashboard |
| `Products.UnlockInstant` | 49 R$ | 0 — isi ID DevProduct dari dashboard |
| `AdminUserIds` | — | kosong — isi `[UserId] = true` untuk `;event` |

Setelah isi: rebuild + publish ulang. Jangan mengarang ID — hanya dari dashboard
Roblox. Jangan beri token Roblox ke siapa pun (repo tidak mempublish otomatis).

## Aset (hasil audit 9 Nov 2026)

- `src/Shared/AssetMap.luau`: **104 kunci, semua `""`** (0 terisi = UPLOAD_PENDING,
  belum ada yang bisa dipublish dengan gambar). Jangan isi ID karangan.
- `assets/generated/`: **34 file gambar + `manifest.json`** (1 icon game +
  22 tanaman + 3 thumbnail + 8 ikon UI). Manifest 34 entri, cocok dengan disk
  (`manifest-matches-disk` PASS, `assets-openable` 34 file OK, semua UPLOAD_PENDING).
- `assets/out/`: **92 PNG placeholder PIL + `.gitkeep`** — JANGAN upload untuk
  publikasi (hanya varian mutasi opsional pasca-22-base lolos moderasi).
- `assets/workflows/`: 3 file (`game_icon.json`, `game_thumbnail.json`, `plant_icon.json`).
- Referensi kode resolve ke kunci yang ada: `InventoryUI` (ikon profil),
  `PlotVisuals` (Decal plot, fallback bila ID kosong), `UiIcons` (ikon UI,
  fallback teks). Tidak ada `rbxassetid` hardcoded di `src/` (satu-satunya
  kemunculan adalah contoh di komentar). Game tetap jalan tanpa aset
  (fallback bola warna + suara bawaan).

## Loop inti

Tanam (30 dtk–75 mnt) → panen/offline max 8 jam → jual → beli langka →
steal tahan 3 dtk (lock 60 dtk) → rebirth 1 jt = multiplier +1x.

## Kode test / admin

- Redeem: `RILIS100K` (100 rb), `HUJANKOPI` (50 rb), `GACOR2026` (250 rb).
- Admin chat: `;event <nama> [menit]` (hanya `AdminUserIds`, mis. `;event rush 1`).
- Daily: 500 → 150 rb streak 7 hari.

## Dokumen lain

- `docs/GDD.md`, `docs/QA.md`, `docs/KNOWN_ISSUES.md` (sisa terbuka yang jujur).
- `docs/RELEASE_CHECKLIST.md` (gate mesin vs gate owner/manusia).
- `docs/ROLLBACK_PROCEDURE.md` (backup & rollback untuk owner).
- `docs/ROBLOX_ASSET_UPLOAD.md`, `docs/ROBLOX_PUBLISHING.md` (langkah manual).
- File audit historis (`MASTER*_AUDIT.md`, `FINAL_*`) adalah arsip — skor lama
  di dalamnya tidak diubah.

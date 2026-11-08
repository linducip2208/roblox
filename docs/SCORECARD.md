# SCORECARD 100/100 — Steal a Kebun (8 Nov 2026)

Aturan: 100 = ada bukti. Tanpa bukti Studio/produk-ID = bukan 100.
Legenda bukti: [K]=kode, [B]=build, [V]=verify.py, [S]=simulasi, [G]=ComfyUI,
[T]=butuh tes Studio, [O]=butuh owner (ID/upload).

| # | Kategori | Skor | Status | Bukti |
|---|---|---|---|---|
| 01 | Core gameplay | 85 | NOT TESTED | [K][B] loop lengkap; [T] 8-player |
| 02 | Plant & seed | 85 | NOT TESTED | [K][V] 22 item valid; [T] tanam |
| 03 | Growth & harvest | 85 | NOT TESTED | [K] IsGrown+income; [T] timing |
| 04 | Economy & progression | 90 | PARTIAL | [K][S] sim+scaling; tanpa data live |
| 05 | Inventory | 85 | NOT TESTED | [K] InventoryUI+service; [T] visual |
| 06 | Shop & restock | 90 | PARTIAL | [K][V] stok real-time; [T] beli 8p |
| 07 | Stealing | 85 | NOT TESTED | [K] atomik+validasi; [T] live |
| 08 | Base protection | 85 | NOT TESTED | [K] lock/safezone; [T] live |
| 09 | Treasure Hunt | 85 | NOT TESTED | [K] multi-spot persist; [T] alur |
| 10 | Riddle & compass | 90 | PARTIAL | [K][V] jawaban server-only; [T] UX |
| 11 | Digging & rewards | 85 | NOT TESTED | [K] radius+kunci+sekali; [T] live |
| 12 | Mutations & rarity | 90 | PARTIAL | [K][S] rate+EV; tanpa data live |
| 13 | Rebirth | 85 | NOT TESTED | [K] scaling linear; [T] live |
| 14 | Daily rewards | 85 | NOT TESTED | [K] %Y%j; [T] lintas hari |
| 15 | Redeem codes | 85 | NOT TESTED | [K] sekali pakai; [T] live |
| 16 | Leaderboards | 80 | NOT TESTED | [K] dasar; [T] live |
| 17 | Events | 85 | NOT TESTED | [K] katalog 4+guard; [T] Sabtu |
| 18 | Saving & loading | 90 | PARTIAL | [K] loadedOk+retry; TANPA tes DataStore live |
| 19 | Migration | 90 | PARTIAL | [K] skema v2; tanpa data lama live |
| 20 | Session safety | 80 | NOT TESTED | [K] lock fail-open; [T] 2 server |
| 21 | Remote security | 90 | PARTIAL | [K] type-check semua; tanpa uji exploit live |
| 22 | GamePass | 60 | BLOCKED | [K] integrasi benar; [O] ID=0 nonaktif |
| 23 | DevProduct | 60 | BLOCKED | [K] receipt idempoten; [O] ID=0 nonaktif |
| 24 | UI/UX | 75 | PARTIAL | [K] 7 layar; tanpa cek visual/aspek |
| 25 | Mobile | 50 | NOT TESTED | [T] device + touch |
| 26 | PC | 50 | NOT TESTED | [T] Play test |
| 27 | World & map | 80 | PARTIAL | [K] MapBuilder; tanpa polish/rambu |
| 28 | Visual assets | 85 | PARTIAL | [G][V] 26 file OK; [O] upload+moderasi |
| 29 | Performance | 75 | PARTIAL | review; tanpa profiling |
| 30 | Error handling | 90 | PARTIAL | [K] pcall+validasi; tanpa uji fault live |
| 31 | Onboarding | 80 | PARTIAL | [K] tutorial; tanpa user baru |
| 32 | Retention | 80 | PARTIAL | sistem ada; tanpa data |
| 33 | Accessibility | 75 | PARTIAL | TextScaled; tanpa cek device |
| 34 | Multiplayer | 40 | NOT TESTED | [T] gate: 8-player Studio |
| 35 | Publikasi | 30 | BLOCKED | [O] asset+ID+tes; dok siap |

**Verdict: BUKAN PUBLICATION READY.** Rata-rata tertahan oleh [T] dan [O].
Tidak ada 100 palsu. Jalur ke rilis: owner upload 26 gambar + isi 4 ID +
Play test 8 player centang QA.md → skor 22/23/28/34/35 naik.

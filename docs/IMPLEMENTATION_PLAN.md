# IMPLEMENTATION PLAN — status eksekusi Master Directive

Legenda: DONE = diimplementasi + build PASS. NEXT = butuh Studio/manual.

## Phase 1 Audit — DONE
- Audit penuh 22 modul, docs/MASTER_AUDIT.md + ARCHITECTURE.md. Git tag `audit-baseline`.

## Phase 2 Gameplay — DONE (kode)
- Plant 22 item + 7 rarity + mutasi 4 varian (70/15/10/5, x1/x5/x3/x10). Config terpusat.
- Steal atomik + fair (lock 60s+10/rebirth+10/VIP, channel 3 dtk, cooldown 5 dtk).
- Shop restock 5 mnt, Secret/EventOnly terkendali.

## Phase 3 Treasure Hunt — DONE (kode)
- 10 riddle berurutan, hint bertahap (gratis/cooldown atau 1000 koin), kompas kasar,
  gali radius 8 + sekop + kunci, multi-spot persist, reward sekali klaim.
- Belum: varian riddle mingguan (mudah tambah di TreasureConfig + TreasureAnswers).

## Phase 4 Ekonomi — DONE (dokumen)
- docs/ECONOMY_BALANCE.md. Tidak ada statistik pasar eksternal yang dipakai.

## Phase 5 Data & Security — DONE (kode)
- loadedOk, retry 3x, skema v2 + migrasi, snapshot tanpa transient, BindToClose 8 dtk.
- Session ownership ganda (2 server tulis bersamaan) BELUM ditangani penuh (butuh
  MemoryStore lock — NEXT, dicatat di KNOWN_ISSUES).

## Phase 6 World — PARTIAL
- MapBuilder: 8 plot + plaza + shop + spawn. NEXT: penamaan zona sesuai TreasureConfig,
  rambu, lighting (butuh edit di Studio).

## Phase 7 ComfyUI — IN PROGRESS
- Server 127.0.0.1:8188 hidup, RTX 4060, model SDXL Lightning + upscaler tersedia.
- `tools/comfy_batch.py` antre 26 gambar → `assets/generated/` + manifest. Workflows di
  `assets/workflows/` (menyusul setelah batch pertama sukses).

## Phase 8 UI/UX — PARTIAL
- Sistem warna/spacing konsisten parsial; panel responsif dasar (TextScaled).
- NEXT: polish di Studio (Sesuaikan urutan panel, ikon setelah upload AssetMap).

## Phase 9 Onboarding — DONE (dasar)
- Tutorial 3 langkah + HUD + notifikasi steal/event/daily.

## Phase 10 Events — PARTIAL
- `EventManager` generik (nama/durasi/multiplier) + auto Sabtu. NEXT: tambah Golden
  Harvest/Treasure Rush sebagai entri konfigurasi + kalender di docs.

## Phase 11 Monetisasi — DONE (kode, ID menunggu)
- ProcessReceipt benar (granted-once), GamePass check server-side, Config terpusat.
- ID produk masih 0 → isi di dashboard, TIDAK ada janji earning.

## Phase 12 Performa — DONE (review)
- Tick 1 dtk ringan, kompas on-demand, visual 5 dtk per plot sendiri, koneksi dibersihkan
  saat leave. Target 8 pemain.

## Phase 13 QA — IN PROGRESS
- `rojo build` PASS. Studio multiplayer NOT TESTED. docs/QA + TEST_RESULTS + KNOWN_ISSUES.

## Phase 14 Polish — PARTIAL
- Placeholder teks masih ada di beberapa tombol (diisi setelah ikon upload).

## Phase 15 Release — NEXT
- docs/ROBLOX_PUBLISHING + STORE_LISTING + UPDATE_NOTES + FINAL_AUDIT (menyusul di pesan ini).

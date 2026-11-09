# MASTER8 RELEASE READINESS — penilaian independen Agen 10 (9 Nov 2026)

Basis bukti: `python tools/verify.py` aktual **44 PASS / 0 FAIL / 2 BLOCKED / 6 NOT TESTED**,
Selene 0/0, StyLua bersih, `src/` 31 modul, 16 remote (parity OK, 14 fungsi rate-limited),
`Config.luau` (ID produk 0, `AdminUserIds` kosong), `AssetMap.luau` 104 kunci semua `""`,
`git status` bersih, tidak ada secret/credential di `src/` (satu-satunya `rbxassetid`
adalah contoh di komentar).

Aturan skor: 95 hanya bila bukti cukup. Semua yang butuh Studio/produksi = Studio-gated,
otomatis di bawah 95 + alasan. Tidak ada 95 di bawah ini — jujur beta-readiness.

| # | Kategori | Skor | Bukti / alasan |
|---|---|---|---|
| 1 | Gameplay (tanam/panen/treasure/event/rebirth) | 80 | Kode + verify semantik (order/lockout/cap) kuat; TAPI 0 menit play test → fungsional = PARTIAL. Gate: Sesi 1+3 runbook. |
| 2 | Multiplayer (8-pemain, steal channel) | 70 | Channel/commit atomik + anti-self/teleport ada di kode; TAPI belum pernah 2/8 klien. Gate: Sesi 2+3. |
| 3 | Security (validasi/rate-limit/anti-exploit) | 82 | 13 handler arg-guard, floor+range, no-leak publik, client tanpa DS — terbaik di repo; TAPI uji bobol manual belum jalan. Gate: Sesi 2. |
| 4 | DataStore integrity (fencing/session) | 80 | UpdateAsync + token+generasi + verify-sebelum-commit + clamp load + offline 2-cap; TAPI belum uji 2-server/shutdown/API-live. Gate: Sesi 4. |
| 5 | Ekonomi/balance | 75 | 22 item skema lengkap, restock 5 mnt, Secret luar shop, cap per-tick; TAPI belum ada data sesi/retensi. Gate: metrik beta Sesi 6. |
| 6 | Monetisasi | 60 | Kabel nonaktif-aman by design (ID 0), receipt idempoten; TAPI 0 ID terisi, 0 sandbox purchase. Gate: Sesi 5. |
| 7 | UI/UX | 78 | Registry eksklusif, UiTheme penuh, tanpa rogue-Visible/hardcode/TextScaled, constraint 3 panel; TAPI belum screenshot/emulasi. Gate: Sesi 1+6. |
| 8 | Mobile | 65 | Constraint + font eksplisit + Tutorial 320px direncana; TAPI 0 device fisik, 0 screenshot notch/portrait. Gate: Sesi 6. |
| 9 | World/Map | 76 | MapBuilder runtime 8 plot + plaza + spawn aman (klaim perbaikan terverifikasi pola kode); TAPI belum lihat spawn di Studio. Gate: Sesi 1. |
| 10 | Performance | 72 | Polling/HUD 1 Hz + cap tertulis; TAPI 0 profiling 8-klien. Gate: Sesi 3. |
| 11 | Release/beta readiness | 55 | Mesin hijau penuh + rollback jujur + tanpa janji publik; TAPI 6 NOT TESTED + 2 BLOCKED owner + 0 metrik tester. BETA GATED. |

## Gate beta (tidak bisa dinego)

1. Sesi 1–3 `docs/STUDIO_QA_RUNBOOK.md` + centang `docs/QA.md` → PRIVATE BETA.
2. Sesi 4–6 + like >85% + sesi >10 mnt dari ±20 tester → PUBLIKASI.
3. Tanpa bukti di atas: **NOT READY — CODE WORK COMPLETE, STUDIO TEST REQUIRED.**
4. Produksi terdokumentasi: `SaveKey StealKebun_v1` / `SCHEMA_VERSION 2`, MemoryStore
   `KebunSessions_v1` TTL 300 dtk / heartbeat 60 dtk, autosave 120 dtk, clamp cash
   0–1e15, offline 8 jam + 50% syarat rebirth; rollback via `SaveKey` baru + `git revert`.
5. Kebersihan: tanpa secret/credential, tanpa file sementara ter-commit
   (`.gitignore` menutup `*.tmp`, `game.rbxlx`, biner `tools/`), `git status` bersih.

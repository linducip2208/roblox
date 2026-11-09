# MASTER8 BUG REPORT — Steal a Kebun (9 Nov 2026)

Baseline `befb436` (tag `audit-baseline-mc8`) → integrasi Master 8.
Semua klaim di bawah berbasis sumber + gate mesin hijau
(verify 52/0/2/6, Selene 0/0/0, StyLua bersih, build PASS).

## P0 — data-loss / exploit (semua DIPERBAIKI, 0 terbuka)
- **P0-1 savedOnLeave tak pernah dibersihkan** (A6→A3): rejoin server sama =
  autosave + leave-save mati permanen (data loss diam-diam). FIX: reset di
  `ClaimSession` dua jalur (`SaveSystem.luau:164,190`). Harness 21/21.
- **P0 audit keamanan** (A2): uang (spend-dulu + refund snapshot-Set + clamp),
  duplikat transaksi (receipt dedupe→grant→save→unmark), steal atomik —
  bertahan dari 100+ payload `regression_exploit.py` 8/8. Tidak ada P0 terbuka.
- **Stale-writer** (A3): 21 skenario fencing termasuk stale-save pasca-commit
  DITOLAK, data baru utuh. Tidak ada P0 terbuka.

## P1 — DIPERBAIKI
- A2 `Main.server.luau`: hint intip-urutan + kuota hangus (gate urutan +
  rollback), channel gantung `nochar`, float probing jawaban (`% 1`),
  pola uid/tool, `RequestStock` → `table.clone`.
- A3 `SaveSystem.luau`: guard payload 4MB pre-UpdateAsync, backoff hemat,
  `loadedOk=false` disconnect-saat-load, ReleaseSession ephemeral early-return.
- A4: `RestoreSpots` validasi xyz (korup dilewat, bukan join-abort);
  `Leaderboard.Attach` guard duplikat; safezone cache + rebind;
  `PlotManager` baca `Config.MutationRate` (fallback, EV 2.25 tetap).
- A5: pulse debounce 0.5s; sound backstop destroy 5s.
- A7 `GamepassHandler.luau`: receipt tanpa PurchaseId → retry; guard ID 0
  sebelum `UserOwnsGamePassAsync`.
- Orkestrator: `Analytics.Flush()` + wiring BindToClose (tutup window 60 dtk);
  `LockBase` spawn pakai rebirth+VIP aktual.

## P2 / catatan desain (DITUNDA dengan alasan, bukan diabaikan)
- **Secret tanpa suplai**: 2 Secret tak bisa dibeli (win-condition koleksi tanpa
  sumber selain steal/event) — keputusan desain owner, tak diubah.
- **R3** polling dipertahankan (~1 req/dtk, push tak verifikabel).
- **R4** cache VerifyLock DITOLAK (keamanan > latensi).
- **R5** refresh inkremental DITUNDA (butuh uji visual).
- **GamePass live-check** tanpa cache TTL (tambah di Main saat lock/refresh —
  rawan throttle di 8 pemain; perlu keputusan owner, file bukan milik A7).
- **Redeem permanen** di source (rotasi manual owner).
- **Duplikasi multiplier** `MoneyService:11` vs `SaveSystem:448`,
  `Config.Event` warisan vs katalog, nama keras tanpa konstanta — kosmetik arsitektur.
- **Analytics ≤60 dtk hilang saat crash** — diterima (bukan data pemain).

## Belum terselesaikan (butuh owner/Studio — BUKAN bug kode)
- BLOCKED (2): 4 ID produk + AdminUserIds = 0.
- NOT TESTED (6): playtest 1/2/8, DataStore live, purchase asli, device visual,
  2-server, shutdown. Prosedur: `docs/STUDIO_QA_RUNBOOK.md`.

# MASTER AUDIT — Steal a Kebun (7 Nov 2026)

Metode: baca penuh 22 modul Luau + default.project.json + docs. Semua temuan di bawah
diverifikasi langsung di kode (bukan asumsi). Perbaikan yang sudah diterapkan ditandai [FIXED].

## Ringkasan
- Struktur Rojo valid, build PASS (`rojo build` → game.rbxlx 53KB).
- 0 TODO di kode, tetapi ditemukan 2 bug RUSAK, 9 RISIKO, 1 celah keamanan jawaban riddle.

## Temuan kritis (sudah diperbaiki)
1. [RUSAK][FIXED] `ShopUI` deadlock: `WaitForChild("EventState")` top-level, remote hanya
   dibuat malas di `EventManager`. → `EventState` sekarang dibuat di `Main`.
2. [RUSAK][FIXED] Transfer steal tidak atomik: victim kehilangan grown/mutasi saat thief
   penuh (refund pakai `Plant` baru + key `tmp_` fiktif). → cek slot dulu, kembalikan slot asli.
3. [KEAMANAN][FIXED] Kunci jawaban riddle di `Shared/TreasureConfig` (terbaca exploiter
   via ReplicatedStorage). → pindah ke `Server/TreasureAnswers.luau`.
4. [DATA-LOSS][FIXED] `SaveSystem.Load` gagal → cache default → autosave timpa data cloud.
   → flag `loadedOk`, skip save jika belum loaded, retry 3x, kick saat join jika load gagal.
5. [PROGRESS][FIXED] Spot treasure tunggal menimpa riddle sebelumnya + hilang saat
   disconnect. → multi-spot per riddle + persist `treasure.spots` + restore saat join.
6. [EXPLOIT][FIXED] `MoneyService.Spend` lolos nilai negatif; `Add` assert (hang client).
   → validasi tanpa throw, clamp setelah multiplier.
7. [LOGIKA][FIXED] `UnlockInstant` malah me-lock base 60s. → `StealSystem.Unlock`.
8. [LOGIKA][FIXED] `EventManager.Start` ganda menimpa timer (task lama matikan event baru).
   → guard + token generasi.

## Temuan sedang (sudah diperbaiki)
9. Remote tanpa type-check (`RequestBuy/Redeem/Steal/BuyTool`) → hang/error client. → validasi tipe + panjang.
10. UID steal manual tanpa validasi milik/grown. → validasi di `RequestSteal`.
11. Plot Owner di-claim malas oleh visual loop (1 pemain 1 plot, 7 plot mati). → assign permanen saat join, release saat leave; visual hanya plot sendiri.
12. `Secret` tampil di Shop (janji palsu). → disembunyikan di client, server tetap tolak.
13. Luck hilang saat relog (memori saja). → persist `profile.luckUntil`.
14. Daily streak rusak saat tahun baru (`yday`). → kunci `%Y%j`.
15. `ShopRotation`/`MutationRate` server-only vs Shop client statis — by design, didokumentasikan.

## Sisa yang disengaja (bukan bug)
- `AssetMap` kosong → fallback bola warna (rencana upload bertahap).
- `TreasureConfig` jawaban dipindah; `Choices` tetap di Shared (aman, tanpa kunci).
- `Analytics.Buy(0)` untuk progres riddle — counter kasar, bukan uang.

## Yang belum bisa diverifikasi (butuh Studio)
- Play 8 player, steal channel 3 detik real, DataStore produksi, GamePass/DevProduct asli.
- Semua ditandai NOT TESTED di docs/TEST_RESULTS.md.

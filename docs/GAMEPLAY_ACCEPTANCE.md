# GAMEPLAY ACCEPTANCE — Steal a Kebun (Agen 3: Gameplay & Economy)

Tanggal: 2026-11-09. Cara baca status:
- **PASS** = terbukti ganda: kutipan kode (path:line) + simulasi `tools/sim_economy.py` yang
  **dieksekusi dan lolos** (exit 0; tiap uji exploit benar-benar mengeksekusi model, bukan cek string).
- **PARTIAL** = logika kode terverifikasi, tapi butuh konfirmasi live di Studio.
- **NOT TESTED** = wajib live di Studio (render/join/reconnect), tidak diklaim lolos.
- **BLOCKED** = terhalang faktor luar (tidak ada pada putaran ini).

Catatan jujur: tanpa sesi Studio, semua alur yang menyentuh client/render/join live
**bukan PASS**. Hasil sim terakhir: **25/25 lolos**.

| # | Alur | Bukti kode | Bukti simulasi | Status |
|---|------|------------|----------------|--------|
| 1 | Join → sesi diklaim dulu, gagal load = kick (tak ada main tanpa lock) | `src/Server/Main.server.luau:709-723` (`ClaimSession`, retry load, kick + `ReleaseSession`) | — (butuh live DataStore/MemoryStore) | NOT TESTED (butuh Studio) |
| 2 | Profil → default tervalidasi, cash awal = `StartingCash` | `src/Server/MoneyService.luau:16-18` (`InitPlayer` pakai `profile.cash` tervalidasi) | — (butuh live load) | NOT TESTED (butuh Studio) |
| 3 | Spawn → proteksi 60 dtk anti-steal saat join | `src/Server/StealSystem.luau:34-40` (`LockBase`; dipanggil saat join `Main.server.luau:740`) | — (butuh live karakter) | NOT TESTED (butuh Studio) |
| 4 | Plot → 1 pemain = 1 plot, visual hanya dari slot milik sendiri | `src/Server/Main.server.luau:674-690` (`assignPlot`/`releasePlot` via `Owner`) | — (butuh live workspace) | NOT TESTED (butuh Studio) |
| 5 | Beli → Spend-dulu lalu tanam, gagal tanam = refund; slot tak tertimpa | `src/Server/Main.server.luau:164-183` (cek dana → `Spend` → `Plant` → rollback `Set(before)`); `src/Server/PlotManager.luau:9-16` (`FindFreeSlot`) | `tanam_slot_sama_ditolak` PASS | PASS |
| 6 | Tanam → roll mutasi 70/15/10/5 sesuai Config, EV 2.25x | `src/Server/PlotManager.luau:28-36`; `src/Shared/Config.luau:55-61` | `EV mutasi dipakai: 2.25x` (model memakai EV yang sama) | PASS |
| 7 | Tumbuh → income hanya dari slot grown; cap per-tick | `src/Server/PlotManager.luau:46-52` (`IsGrown`); `:54-70` (`TickIncome`, cap `MaxCashPerTick`) | Model `_run` hanya mengakumulasi slot `t >= grow` | PASS |
| 8 | Panen → tidak ada duplikat: steal = PINDAH (slot korban dihapus), panen ganda gagal | `src/Server/Main.server.luau:374-379` (cek `IsGrown` → hapus slot korban → `AddStolenSlot`, gagal = kembalikan slot ASLI) | `panen_ganda_ditolak`, `steal_pindah_bukan_duplikat` PASS | PASS |
| 9 | Reward → SEMUA uang via `MoneyService.Add`; negatif/NaN/inf ditolak, reward gila di-clamp | `src/Server/MoneyService.luau:51-66` (tolak `<0`/non-finite `:52-55`, clamp `MaxCashPerTick*10` `:59-63`); `Spend` `:68-78`; `Set` tervalidasi `:80-89` | `uang_negatif/nan/inf_ditolak`, `spend_lebih/negatif_ditolak`, `reward_gila_diclamp` PASS | PASS |
| 10 | Inventory → otoritatif server; `SpendKeys` tolak `n<=0` (negatif = tambah kunci) | `src/Server/InventoryService.luau:38-49` (guard `:41-43`, floor `:44-47`);dig pakai kunci `src/Server/TreasureService.luau:254` | `kunci_negatif_ditolak`, `kunci_ganda_ditolak` PASS | PASS |
| 11 | Shop → stok atomik, Secret tak dijual, EventOnly digate event | `src/Shared/ShopRotation.luau:60-67` (`Take` atomik); `src/Server/Main.server.luau:156-160` (gate Secret/EventOnly) | — (restock 5 mnt butuh live) | PARTIAL |
| 12 | Steal → lock/cooldown/channel 3 dtk/itemLocks; channel ditimpa = lock lama DIBEBASKAN (fix R1 Agen 1); batal/timeout/pergi = `ClearChannel` | `src/Server/StealSystem.luau:84-97` (perebutan `:84-87`, bebas-lock `:90-93`); `:104-110` (`ClearChannel`); `:116-124` (pergi); batal via `ClearChannel` `Main.server.luau:348-401` | `steal_simultan_satu_pemenang`, `steal_item_tak_tersedia_ditolak`, `steal_belum_grown_ditolak`, `steal_ganti_target_bebaskan_lock_lama`, `steal_thief_penuh_ditolak` PASS | PASS |
| 13 | Treasure → urutan wajib, anti-bruteforce (cooldown + lockout 5x), kunci per gali, kompas tanpa koordinat | `src/Server/TreasureService.luau:85-99` (cooldown, `sudah_selesai`, `bukan_urutan`); `:123-129` (lockout); `:254-259` (kunci+gali); `:212-220` (jarak kasar + arah mata angin) | `riddle_lompat_urutan_ditolak`, `riddle_solve_sekali`, `riddle_lockout_5x_gagal` PASS | PASS |
| 14 | Daily → 1 claim/hari (kunci `%Y%j` aman tahun baru), streak reset bila skip | `src/Server/DailyReward.luau:14-16` (`CanClaim`); `:18-33` (streak + reset, nil-safe) | `daily_ganda_ditolak` PASS | PASS |
| 15 | Rebirth → syarat linear, dana kurang ditolak, reset slots+cash, multiplier naik | `src/Server/Main.server.luau:219-225` (cek `RebirthRequirementFor` → reset → `Set(StartingCash)`); `src/Server/MoneyService.luau:80-89` (`Set` clamp ≥0) | `rebirth_dana_kurang_ditolak`, `rebirth_reset_benar` PASS; skenario `_run` capai rebirth-1/2/3 | PASS |
| 16 | Offline → cap 8 jam + cap 50% syarat rebirth (anti kaya instan) | SaveSystem `Load` (cap `OfflineGrowthCap`, `OfflineMaxPctOfRebirth`; read-only bagi Agen 3) | `offline_cap_8jam`, `offline_cap_50pct_rebirth` PASS | PASS |
| 17 | Rejoin → spot harta dipulihkan dari save; sesi ganda ditolak | `src/Server/TreasureService.luau:28-38` (`RestoreSpots`), `:271-273` (`BindUid`); session lock `Main.server.luau:712` | — (butuh live disconnect/rejoin) | NOT TESTED (butuh Studio) |
| 18 | Multiplayer aman → rate-limit per remote + itemLocks + session lock | `src/Server/Main.server.luau:58-91` (`RATE_LIMITS`); `src/Server/StealSystem.luau:84-93` | `steal_simultan_satu_pemenang` PASS | PASS |
| 19 | UI otoritatif → client hanya render push server; leaderstats dari `MoneyService` | `src/Server/Main.server.luau:406-411` (push `tick`); `src/Server/Leaderboard.luau:21-32` (sync dari server) | — (render butuh live client) | PARTIAL |
| 20 | Reconnect aman → save saat leave/autosave, skip save tanpa lock | `Players.PlayerRemoving` + autosave (SaveSystem, read-only); `VerifyLock` sebelum commit | — (butuh live disconnect) | NOT TESTED (butuh Studio) |

## Temuan & perbaikan Agen 3 (tidak ubah balancing/mekanik)

1. **R1 (dari Agen 1, sudah ter-cover) — `itemLocks` bocor saat channel ditimpa.**
   `StealSystem.RequestSteal` menimpa `channels[thief]` tanpa membebaskan `itemLocks[uid-lama]`,
   sehingga item lama terkunci selamanya. Diperbaiki di `src/Server/StealSystem.luau:88-93`
   (bebaskan lock lama milik thief sebelum mengunci item baru). Jalur lain sudah aman tanpa
   perubahan: batal/timeout/victim-pergi → `ClearChannel` (`:104-110`, dipanggil di semua cabang
   gagal `Main.server.luau:348-401`); thief pergi → `PlayerRemoving` (`:116-124`); sukses →
   `ClearChannel` setelah `SetCooldown`. Simulasi: `steal_ganti_target_bebaskan_lock_lama` PASS.
2. **`MoneyService.Set` tanpa validasi** (`:80-89`): asal `Set` negatif/NaN meracuni saldo.
   Sekarang `finite → floor → clamp [0, 1e15]`. Menutup juga jalur refund `Set(before)` di shop/tools.
3. **`PlotManager.AddStolenSlot` nil-index** (`:78-81`): `Items.ById[bad]` → index `.GrowthTime`
   pada `nil` = error. Sekarang return `item_invalid`.
4. **`InventoryService.SpendKeys` kuantitas gila** (`:41-47`): `SpendKeys(p, -5)` menambah kunci.
   Sekarang tolak `n <= 0`/non-number + `floor`.
5. **`DailyReward` nil-safe** (`:15`, `:27`): `(lastDailyYday or "")`; perilaku profil valid identik.
6. Ditemukan saat audit tapi **di luar kepemilikan** (tidak diubah Agen 3): urutan
   cek-dana→tanam→`Spend` di shop rawan TOCTOU (slot gratis bila `Spend` gagal balapan).
   Saat dokumen ini ditulis pemilik `Main.server.luau` sudah menanganinya
   (pola Spend-dulu + refund `Set(before)`, `Main.server.luau:164-183`).

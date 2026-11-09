# MASTER 8 — Audit Arsitektur (Principal Architect, Agen 1)

> Sifat: READ-ONLY terhadap `src/`, `tools/`, `assets/`. Satu-satunya file yang ditulis agen ini.
> Baseline: commit `befb436` (tag `audit-baseline-mc8`). Verify saat audit: **44 PASS / 0 FAIL / 2 BLOCKED / 6 NOT TESTED**
> (BLOCKED = `product-ids`, `admin-configured`; NOT TESTED = 6 skenario Studio). Selene 0/0, StyLua rapi.
> Tidak ada klaim PASS Studio — semua yang butuh Play test tetap NOT TESTED.

## 1. Inventaris modul (31: Shared 8, Server 16, Client 7)

| # | Modul | Peran |
|---|-------|-------|
| S1 | `Shared/Config.luau` | Konstanta + balance (leaf, tanpa require) |
| S2 | `Shared/Items.luau` | 22 item + `ById` (leaf) |
| S3 | `Shared/ShopRotation.luau` | Stok FOMO restock 5 mnt; require `Items` |
| S4 | `Shared/TreasureConfig.luau` | 10 riddle + spawn + reward (leaf; jawaban TIDAK di sini) |
| S5 | `Shared/AssetMap.luau` | ID aset upload + `Get()` (leaf) |
| S6 | `Shared/UiTheme.luau` | Satu-satunya sumber gaya UI (leaf) |
| S7 | `Shared/UiPanels.luau` | Satu-satunya pengatur visibilitas panel (leaf) |
| S8 | `Shared/UiIcons.luau` | Ikon tombol; require `AssetMap` |
| V1 | `Server/Main.server.luau` | Wiring remote + income/steal loop + join/leave (orkestrator, BUKAN library) |
| V2 | `Server/SaveSystem.luau` | Load/save + fencing gen + session lock (otoritas data) |
| V3 | `Server/MoneyService.luau` | Satu-satunya penulis cash; require `Config` |
| V4 | `Server/PlotManager.luau` | Slot tanam/income; require `Config`, `Items` |
| V5 | `Server/StealSystem.luau` | Channel/lock/cooldown steal; require `Config` |
| V6 | `Server/MapBuilder.luau` | Bangun map idempoten (leaf server) |
| V7 | `Server/PlotVisuals.luau` | Render crop; lazy `AssetMap` via `FindFirstChild` (sengaja, anti-yield) |
| V8 | `Server/Leaderboard.luau` | leaderstats; lazy `MoneyService`+`SaveSystem` di dalam thread |
| V9 | `Server/EventManager.luau` | Event katalog; require `Config`, lazy `Analytics` |
| V10 | `Server/GamepassHandler.luau` | Luck/unlock; require `Config`, `SaveSystem` (WaitForChild), lazy `StealSystem`/`MoneyService` |
| V11 | `Server/TreasureService.luau` | Logika harta server-only; require `TreasureConfig`, `TreasureAnswers`, `EventManager`, lazy `InventoryService` |
| V12 | `Server/TreasureAnswers.luau` | Kunci jawaban (leaf, SERVER ONLY) |
| V13 | `Server/InventoryService.luau` | Kunci/sekop/kompas (leaf) |
| V14 | `Server/DailyReward.luau` | Streak 7 hari (leaf) |
| V15 | `Server/RedeemCode.luau` | Kode sekali pakai (leaf) |
| V16 | `Server/Analytics.luau` | Agregat DataStore + flush 60 dtk (leaf) |
| C1 | `Client/Hud.client.luau` | Cash/income/lock + nav `UiPanels.Toggle` |
| C2 | `Client/ShopUI.client.luau` | Shop/stok/lock/rebirth/daily/redeem |
| C3 | `Client/InventoryUI.client.luau` | Profil + tombol gamepass/devproduct + mute |
| C4 | `Client/TreasureUI.client.luau` | Riddle/kompas/gali/beli alat |
| C5 | `Client/StealPrompt.client.luau` | ProximityPrompt tahan-E per plot |
| C6 | `Client/Sound.client.luau` | Beep bawaan Roblox, hormati atribut Muted |
| C7 | `Client/Tutorial.client.luau` | Banner 3 langkah |

## 2. Peta dependency (arah require)

```
Config, Items, TreasureConfig, AssetMap, UiTheme, UiPanels,
DailyReward, RedeemCode, InventoryService, MapBuilder, Analytics   (leaf)
  │  │       │                           ▲
  │  ▼       ▼                           │ lazy-FindFirstChild (anti-yield)
  │  ShopRotation(Items)  UiIcons(AssetMap)  PlotVisuals
  │
  ├─ MoneyService(Config)
  ├─ PlotManager(Config, Items)
  ├─ StealSystem(Config)
  ├─ EventManager(Config) ──lazy──▶ Analytics
  ├─ SaveSystem(Config, Items, MoneyService)
  │     ▲
  │     ├─ GamepassHandler(Config, SaveSystem) ──lazy──▶ StealSystem, MoneyService
  │     ├─ TreasureService(TreasureConfig, TreasureAnswers, EventManager) ──lazy──▶ InventoryService
  │     └─ Leaderboard ──lazy (dalam thread)──▶ MoneyService, SaveSystem
  └─ Main.server (mem-require SEMUA di atas + DailyReward, RedeemCode,
                  Analytics, InventoryService, ShopRotation, TreasureConfig)
Client: Hud(UiTheme, UiPanels) · ShopUI(Items, UiIcons, UiTheme, UiPanels)
        InventoryUI(AssetMap, UiTheme, UiPanels) · TreasureUI(UiIcons, UiTheme, UiPanels)
        StealPrompt/Tutorial/Sound (tanpa require Shared selain UiTheme di Tutorial)
```

**Siklus require: TIDAK ADA.** Titik rawan sudah dipecah dengan lazy-require di dalam fungsi/thread:
`TreasureService→InventoryService`, `GamepassHandler→StealSystem/MoneyService`,
`Leaderboard→MoneyService/SaveSystem`, `EventManager→Analytics`, `PlotVisuals→AssetMap`.
`SaveSystem→MoneyService` satu arah (MoneyService tidak require balik). `UiIcons→AssetMap` satu arah.

## 3. Lifecycle & init order

### 3.1 Server (`Main.server.luau`)

1. Require Shared `Config`, `Items` → require `SaveSystem..PlotVisuals`, `ShopRotation` (ShopRotation langsung `Restock()` + spawn thread restock saat di-require).
2. `MapBuilder.Build()` — idempoten: tanah `GroundKebun`, folder `Plots` + `Plot_1..8` (+`Owner=""`, `LockPole`), `TradePlaza`, `Shop`, `SpawnLocation`, rambu, pohon.
3. `getOrCreate` 8 remote inti → require `DailyReward`, `RedeemCode`, `Analytics`, `TreasureService`, `InventoryService`, `TreasureConfig`.
4. Spawn loop income+steal (tick `Config.IncomeTick`), loop visual 5 dtk, `PlayerAdded` admin-chat, `getOrCreate` 8 remote harta, handler `OnServerInvoke/OnServerEvent`, `assignPlot`, `PlayerAdded` join-flow, `ProcessReceipt`, `PlayerRemoving` cleanup.
5. `print("[StealKebun] Main loaded")`.

**Yang Main butuhkan dulu:** `Remotes` dibuat sebelum handler diikat; `MapBuilder.Build()` sebelum `assignPlot` (plot harus ada);
`SaveSystem.ClaimSession → Load → Ensure/BindUid/InitPlayer/RefreshMultiplier/Attach/LockBase/assignPlot`
urutan join-flow tidak boleh dibalik (tanpa lock = tanpa load = kick).

### 3.2 Join flow per pemain (fail-closed)

`ClaimSession` (tolak/kick bila lock hidup di server lain; Studio = ephemeral) → `Load`
(gagal = `ReleaseSession` + `DropCache` + kick, TIDAK pakai default) → `InventoryService.Ensure` →
`TreasureService.BindUid` (restore spot) → `MoneyService.InitPlayer/RefreshMultiplier` →
`Leaderboard.Attach` → `StealSystem.LockBase` (spawn protection) → `assignPlot` → `welcome` defer.

### 3.3 Client init

Semua client memakai `WaitForChild("Shared"/"Remotes"/modul)` — aman terhadap urutan replikasi, kecuali
catatan P2 di §5 (nav HUD vs registrasi panel). `StealPrompt` menunggu `workspace.Plots` (dibuat server saat start).

### 3.4 Konfigurasi Rojo (`default.project.json`)

`ReplicatedStorage.Shared ← src/Shared`, `ServerScriptService.Server ← src/Server`,
`StarterPlayerScripts.Client ← src/Client`, folder kosong `Remotes` + `Workspace.Plots` disiapkan
(diisi saat runtime oleh `getOrCreate` / `MapBuilder`). Batas server/client: client TIDAK me-require modul
Server; satu-satunya jembatan adalah 16 remote + `PlayerGui` + atribut `Muted`.

## 4. Kontrak integrasi (beku — antaragen dilarang mengubah tanpa migrasi)

1. **16 remote, nama + kelas tetap** (`Main.server.luau:38-45, 498-505`):
   `RequestBuy(F)` `RequestSteal(F)` `RequestLock(E)` `RequestRebirth(F)` `RequestDaily(F)`
   `RequestRedeem(F)` `UpdateHud(E)` `EventState(E)` `RequestRiddle(F)` `SubmitAnswer(F)`
   `RequestHint(F)` `CompassPing(F)` `RequestDig(F)` `BuyTool(F)` `RequestStock(F)` `RequestInventory(F)`.
   Payload respons (`{type="tick", cash, mult, locked, income, level}`, `{type="steal_ok"...}`, dsb.)
   hanya boleh tambah field opsional; client harus `tonumber()/tostring()` defensif seperti sekarang.
2. **Profil: tambah field = bump `SCHEMA_VERSION`** (`SaveSystem.luau:18`, kini `2`) + jalur di
   `ValidateProfile`; runtime (`_uid/_baseAt/_baseSession/_baseGen/offlineEarned`) tidak boleh masuk DataStore
   (`stripRuntime`). `InventoryService.Ensure` adalah satu-satunya penambah default `treasure.*`.
3. **Jawaban harta tidak pernah ke client**: `TreasureAnswers` hanya di-require `TreasureService`;
   `PublicRiddle` steril (`Zone=nil`, tanpa index benar) — verify `treasure-no-leak-public` menjaganya.
4. **Ekonomi hanya lewat `MoneyService`** (Add/Spend/Set); refund memakai pola snapshot-`Set`
   (`Main.server.luau:179,186,675,690`) karena `Add` mengalikan multiplier — JANGAN ganti dengan `Add` negatif.
5. **Reward monetisasi hanya dari `ProcessReceipt` terverifikasi** (`GamepassHandler` + `Main:771`);
   tidak ada remote client yang memberi reward; ID `0` = nonaktif aman.
6. **Rate-limit terpusat `RATE_LIMITS`** (`Main.server.luau:61-76`); remote baru wajib didaftarkan + guard argumen.

## 5. Temuan

### P0 — data-loss / exploit: TIDAK DITEMUKAN pada baseline ini

Fencing generasi atomik, tolak-tulis tiga kondisi (`SaveSystem.luau:519-539`), refund snapshot-`Set`,
dan commit steal atomik + restore slot asli (`Main.server.luau:373-399`) semuanya utuh dan terverifikasi.

### P1 — rusak/crash bila terpicu

- **P1-1 (SUDAH DIPERBAIKI di baseline, tinggal dijaga): rejoin server-sama kehilangan autosave.**
  `savedOnLeave[uid]` diset permanen saat leave (`SaveSystem.luau:586,601`); bila user yang sama rejoin
  instance yang sama, autosave + leave-save berikutnya akan dilewati. Baseline SUDAH menetralkan via reset
  di `ClaimSession` (`SaveSystem.luau:164` Studio, `:190` produksi). **Kontrak: setiap jalur masuk sesi baru
  wajib mereset `savedOnLeave`; agen dilarang menghapus dua baris tersebut.**
- **P1-2: `Leaderboard.Attach` (`Leaderboard.luau:5-33`) membuat `leaderstats` tanpa mengecek duplikat.**
  Normal flow (satu Attach per join) aman, tapi pemanggilan ganda (retry join / agen masa depan memanggil ulang)
  menumpuk folder `leaderstats` + thread 2-detik per Attach (leak thread per panggilan). Saran: guard
  `FindFirstChild("leaderstats")` sebelum create. Belum terpicu — P1, bukan P0.

### P2 — lainnya (kualitas/rapuh, tidak merusak saat ini)

- **P2-1 Duplikasi formula multiplier**: `MoneyService.baseMultiplier` (`MoneyService.luau:11-14`) vs
  hitungan offline di `SaveSystem.Load` (`SaveSystem.luau:448`) — dua sumber kebenaran untuk
  `min(1+rebirths*step, Max)`. Berfungsi identik hari ini; berisiko divergen saat tuning.
  DISELESAIKAN 9 Nov 2026 (integrasi): `MoneyService.BaseMultiplier` jadi sumber tunggal,
  dipakai `SaveSystem` offline-calc.
- **P2-2 `Config.MutationRate` mati**: didefinisikan (`Config.luau:64`) tapi tidak pernah di-require;
  `PlotManager.Plant` (`PlotManager.luau:28-36`) memakai ambang hardcode `>95/>85/>70` (konsisten 5/10/15/70
  dengan tabel, tapi terpisah). Satu sumber harus menang.
- **P2-3 `Config.Event` warisan vs katalog `Config.Events`**: `EventManager` memakai katalog +
  `DefaultEvent`, kecuali `AutoSaturday19WIB` yang masih dibaca dari `Config.Event` (`EventManager.luau:92`).
  Kunci mati (`Name/DurationMinutes/IncomeMultiplier`) DIHAPUS 9 Nov 2026 (integrasi) — tanpa ubah perilaku.
- **P2-4 Race nav-vs-registrasi panel (client)**: `Hud` memanggil `UiPanels.Toggle("shop"/"treasure"/"profile")`
  segera saat diklik; urutan eksekusi LocalScript tidak deterministik — klik sebelum `ShopUI/InventoryUI/TreasureUI`
  `Register` → warn + no-op (`UiPanels.luau:39-46`). Fungsional setelah semua load; UX edge-case.
- **P2-5 `Analytics` tanpa flush saat shutdown**: `BindToClose` hanya di `SaveSystem`; antrian analitik
  (≤60 dtk) hilang saat shutdown — didokumentasikan sebagai batas desain, BUKAN data pemain. Tetap dicatat
  agar tidak dianggap bug saat audit angka event.
- **P2-6 `RequestStock` mengembalikan referensi tabel live** (`Main.server.luau:549`) — aman karena
  RemoteFunction menyalin, tapi kontraknya rapuh bila suatu hari dipakai in-process. Snapshot dangkal disarankan.
- **P2-7 Asumsi nama keras terpusat dengan baik** (`SafeZoneName="TradePlaza"`, `"Plot_"`, `"Owner"`,
  `"Crop"`, `"StealPrompt"`) — semua produsen/konsumen konsisten (`MapBuilder`/`StealSystem`/`Main`/`StealPrompt`/
  `PlotVisuals`). Satu-satunya yang tanpa konstanta bersama; ganti nama = pecah diam-diam. Pertahankan
  daftar ini sebagai kontrak (lihat §4).

## 6. Status regresi Master 7 (klaim vs baseline)

| Klaim Master 7 | Hasil audit file |
|---|---|
| Fencing generasi atomik | ✅ UTUH — `fenceAndRead` naik-gen atomik + re-fence idempoten (`SaveSystem.luau:340-390`); transform save tolak (a) gen basi (b) sesi basi job+token (c) basis asing (`:519-539`); verify `fencing-token-gen/verify-strict/release-own` PASS |
| 13 bug fix | ✅ Konsisten — verify 44/0, Selene 0/0, StyLua rapi; tidak ditemukan regresi P0/P1 terbuka dari daftar itu |
| Delta-push HUD (`lastHud`) | ✅ UTUH — snapshot `cash|mult|locked|gained|level` (`Main.server.luau:417-431`), kirim hanya saat berubah, cleanup saat leave (`:792`); client menangani semua `type` yang dikirim |
| Flush analitik | ✅ UTUH — agregat memori + `UpdateAsync` add per kunci harian (`Analytics.luau:25-46`), gagal flush = antre ulang (`:40`); tanpa thread-per-event |
| Refund snapshot-`Set` | ✅ UTUH — 4 titik (`Main.server.luau:179,186,675,690`) memakai `Set(before)` bukan `Add`; tanpa yield antara `Spend` dan `Set` (atomik vs income-tick kooperatif) |
| Pembersihan state per-UserId saat leave | ✅ UTUH — `Main` (`:791-794`), `MoneyService` (`:90-93`), `StealSystem` (`:116-124`), `TreasureService` (`:275-280`), `GamepassHandler` (`:85-87`), `SaveSystem` (`:583-591` + reset rejoin `:164,190`); sisa: P1-2 (Leaderboard thread) |

## 7. Catatan untuk agen 2-8 (bukan perintah, hanya batas)

- Jangan tambah remote/field profil tanpa §4. Jangan pindahkan logika ekonomi ke client.
  `TreasureAnswers` tetap server-only. `Config.MutationRate` / `Config.Event` / duplikasi multiplier
  boleh dirapikan HANYA bila perilaku bit-identik dan verify tetap 44/0.
- Yang TIDAK diaudit di sini (di luar mandat read-only): isi `tools/*.py`, `assets/`, dan 6 skenario
  NOT TESTED Studio (butuh Play test fisik, klaim dilarang).

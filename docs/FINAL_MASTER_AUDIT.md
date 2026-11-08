# FINAL MASTER AUDIT — Steal a Kebun (8 Nov 2026)

## 1. Inventarisasi repository (aktual, bukan asumsi)
- `src/Shared/` (7): Config, Items (22 item), ShopRotation, TreasureConfig (**tanpa jawaban**),
  AssetMap (100 kunci, semua kosong = UPLOAD_PENDING), UiTheme (palet resmi),
  UiPanels (registry visibilitas), UiIcons (ImageLabel + fallback).
- `src/Server/` (14): Main, SaveSystem, MoneyService, PlotManager, StealSystem, MapBuilder,
  Leaderboard, GamepassHandler, EventManager (katalog 4 event), PlotVisuals,
  DailyReward, RedeemCode, Analytics, TreasureService, TreasureAnswers (SERVER ONLY),
  InventoryService.
- `src/Client/` (7): Hud (navigasi Shop/Harta/Profil + income), ShopUI (stok real-time +
  tombol lipat), TreasureUI (terlipat default + tambah ikon), InventoryUI (profil +
  gamepass + mute + lipat), StealPrompt, Tutorial, Sound (mute-aware).
- Tidak ada: `src/World` (map dibangun runtime oleh MapBuilder — disengaja),
  `tests/` Roblox (pengujian runtime butuh Studio — NOT TESTED), CI workflows (tidak ada).
- `game.rbxlx` 115KB hasil `rojo build` PASS. 0 TODO/FIXME di `src/`.

## 2. Dependensi & remote
- 15 RemoteFunction + 2 RemoteEvent dibuat di Main, semua dipakai client ada pasangannya
  (verify.py: remote-parity PASS). Semua 15 fungsi client→server punya rate limit (PASS).
- Tidak ada circular require (Main → semua service; tidak ada yang require Main).

## 3. Temuan kritis & status
| # | Temuan | Status |
|---|---|---|
| 1 | `local until` (keyword) → GamepassHandler gagal compile | FIXED + Selene 0/0 |
| 2 | Koma hilang 10 riddle (script migrasi) → Shared gagal parse | FIXED + build PASS |
| 3 | EventState deadlock ShopUI | FIXED (dibuat di Main) |
| 4 | Jawaban riddle di Shared (bisa dibaca exploiter) | FIXED (TreasureAnswers server-only) |
| 5 | Steal tidak atomik (victim bisa kehilangan item) | FIXED (cek slot dulu + kembalikan slot asli + item lock) |
| 6 | Save timpa data saat load gagal | FIXED (loadedOk + fail-closed + envelope UpdateAsync) |
| 7 | Spot treasure tunggal menimpa + hilang saat relog | FIXED (multi-spot + persist + restore) |
| 8 | Claim sesudah load (jendela tanpa lock) | FIXED (claim dulu, gagal = kick + DropCache) |
| 9 | Receipt belum verifikasi persistensi | FIXED (Save boolean, Granted hanya jika commit) |
| 10 | Phase 1 docs vs implementasi (UiTheme lama, skor usang) | FIXED di sini (lihat §6) |

## 4. Risiko tersisa (jujur, butuh Studio/owner)
- Playtest 8 pemain, DataStore produksi, 2-server lock, purchase asli: NOT TESTED.
- 34 gambar: GENERATED+valid, belum upload/moderasi (BLOCKED).
- 4 ID produk + AdminUserIds = 0 (BLOCKED, fitur nonaktif aman).

## 5. Keputusan arsitektur penting
- Ephemeral Studio: Play lokal tanpa DataStore (fail-closed di produksi). BUKAN mock
  yang menyamar sebagai backend — dibedakan eksplisit via `RunService:IsStudio()`.
- verify.py = satu gerbang (15 cek + Selene + StyLua). Skrip tools portabel via tools/repo.py.
- Tidak ada commit/push dalam sesi ini (sesuai perintah): semua perubahan working tree lokal.

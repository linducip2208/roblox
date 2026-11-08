# ARCHITECTURE — Steal a Kebun

```
ReplicatedStorage
├── Shared/            (client BOLEH baca: Config, Items, ShopRotation, TreasureConfig TANPA jawaban, AssetMap)
│   └── Remotes/       (dibuat Main: RequestBuy/Steal/Lock/Rebirth/Daily/Redeem/Riddle/SubmitAnswer/
│                       RequestHint/CompassPing/RequestDig/BuyTool, UpdateHud, EventState)
├── ServerScriptService/Server/   (otoritas: Main, Save, Money, Plot, Steal, Map, Leaderboard,
│                       Gamepass, Event, PlotVisuals, ShopRotation(require Shared), Daily, Redeem,
│                       Analytics, TreasureService, TreasureAnswers(SERVER ONLY), InventoryService)
└── StarterPlayerScripts/Client/  (tampilan saja: Hud, ShopUI, StealPrompt, Tutorial,
                                  Sound, TreasureUI — TIDAK ADA logika uang/item)
```

## Alur data
1. Join → `SaveSystem.Load` (retry 3x, migrasi skema v2) → gagal total = kick (lindungi data).
2. `MoneyService` satu-satunya penulis cash. `profile.cash` cerminan, disinkron saat save.
3. Income tick 1 dtk: `PlotManager.TickIncome` (raw) → x event → `MoneyService.Add` (x rebirth/pass).
4. Steal: `RequestSteal` (validasi slot+uid) → channel 3 dtk (cek jarak/lock tiap tick) →
   transfer atomik + save kedua belah pihak.
5. Treasure: riddle berurutan → solve = reward + spawn spot server (persist) → kompas
   (jarak kasar) → gali (radius 8 + sekop + 1 kunci) → reward sekali, tidak bisa dobel.
6. Autosave 120 dtk + leave + shutdown (8 dtk). Tanpa `loadedOk` = tidak save.

## Prinsip keamanan
- Client tidak pernah kirim harga, reward, kepemilikan, atau posisi harta.
- Jawaban riddle + posisi spot hanya di memori server + field save (posisi saja).
- Semua RemoteFunction divalidasi tipe/panjang/rate-limit; tidak pernah throw ke client.

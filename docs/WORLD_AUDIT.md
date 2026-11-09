# WORLD AUDIT — Steal a Kebun (Agen 6: World, Map & Game Feel)

Tanggal: 2026 (audit kode statis + verifikasi tool; klaim runtime bertanda NOT TESTED).

## 1. Peta Dunia (dari `src/Server/MapBuilder.luau`)

| Elemen | Posisi / Ukuran | Catatan |
|---|---|---|
| `GroundKebun` | `(0,0,0)`, 400×1×400, atas di y=0.5 | Tanah dasar, CanCollide=true |
| 8 plot `Plots/Plot_1..8` | Lingkaran radius 60, y=1, 16×1×16, atas y=1.5 | 1 pemain = 1 plot via `Owner` (alokasi di `Main.server.luau:633-647`) |
| `LockPole` per plot | `base + (6,4,6)`, 1×8×1 | Indikator, CanCollide=false |
| `TradePlaza` (safezone) | `(0,1,0)`, 30×1×30, atas y=1.5 | Nama sama dengan `Config.SafeZoneName` (`Config.luau:24`). Dipakai `StealSystem.luau:27` via `FindFirstChild(name, true)` |
| `Shop` | `(0,4,-25)`, 12×6×12 (bawah y=1) | Balok rintangan solid; beli via UI, tidak perlu masuk |
| `SpawnLocation` | `(0,4,5)`, 6×1×6, Neutral=true | Di atas plaza (plaza z −15..15, jadi z=5 di dalam plaza) |
| `Rambu_Shop/Plaza/Spawn` | BillboardGui + tiang | Penunjuk arah |
| `TreesKebun` 8 pohon | Radius 95, batang silinder + daun bola | Hiasan, CanCollide=false |
| Treasure spawn | 8 titik di `TreasureConfig.luau:128-137` ± offset 12 (`TreasureService.luau:116-118`) | Semua dalam tanah 400×400; y=3 (dig radius 8, `TreasureConfig.luau:18-22`) |

Layout kasar (tampak atas, +x kanan, +z bawah/selatan):

```
        Shop (0,-25) + Rambu_Shop
   P8(-60,-20)  P7...       P1(60,0)/P5(60,-10)
        [TradePlaza 30x30 + Spawn(0,5)]
   P6(-30,-40)  P4...       P2(45,20)/P3(20,-55)
        Pohon radius 95 (8x) mengelilingi
```

Plot 1..8 (sudut `(i-1)/8*2π`, radius 60): P1 (+x), lalu berputar CCW.
Treasure SpawnPoints (8): `(45,3,20)`, `(-50,3,35)`, `(20,3,-55)`,
`(-30,3,-40)`, `(60,3,-10)`, `(-60,3,-20)`, `(10,3,60)`, `(-15,3,55)` —
catatan: `(60,3,-10)` dan `(-60,3,-20)` berdekatan dengan plot P1/P5/P8,
jadi titik gali bisa muncul di atas/di dekat plot pemain (sengaja: butuh
sekop + kunci + radius 8; tidak merusak plot).

## 2. Daftar Cek

| # | Cek | Status | Bukti |
|---|---|---|---|
| 1 | Duplikat plot / rebuild aman | PASS | `MapBuilder.luau:41-75` validasi per nama `Plot_1..8`; properti diperbaiki ulang (Anchored/CanCollide/Owner/LockPole) tanpa `Instance.new` ganda |
| 2 | Folder/pohon/rambu parsial tidak duplikat | PASS (diperbaiki) | `MapBuilder.luau:126-163` Trees per-nama `Trunk<i>/Leaves<i>`; `Sign` (`:167-182`) bangun ulang GUI bila tiang ada tapi GUI hilang |
| 3 | Kepemilikan plot | PASS (kode) / NOT TESTED (Play) | `Owner` StringValue per plot (`:57-62`); klaim 1 pemain = 1 plot `Main.server.luau:633-647`; visual hanya untuk `Owner == UserId` (`Main.server.luau:407-423`); lepas saat keluar (`:649-666`) |
| 4 | Spawn di plaza, tidak jatuh void | PASS (kode) / NOT TESTED (Play) | Spawn `(0,4,5)` di dalam plaza 30×30 (`MapBuilder.luau:106-117`), Neutral=true; tanah 400×400 menutup semua spawn/plot/treasure |
| 5 | Teleportasi / anti-exploit gerak | PASS (kode, milik Main/Steal) | Batas teleport 150 (`Main.server.luau:293-298`), leash channel 25 + jarak curi `StealDistance+10` (`StealSystem.luau:72`, `Main.server.luau:328`) |
| 6 | Collision | PASS | Berpijak: Ground/Plot/Plaza/Shop/Spawn = CanCollide=true; non-halangi: LockPole/rambu/pohon/crop = CanCollide=false (`MapBuilder.luau:56,74,87,101,148,161,179`; `PlotVisuals.luau:70`) |
| 7 | Terrain/tanah menutup semua titik | PASS | Tanah 400×400 (±200) vs titik terjauh pohon (±95) & treasure (±60+12 offset) & plot (60+8) — semua di dalam |
| 8 | 8 titik treasure konsisten TreasureConfig | PASS | `TreasureConfig.luau:128-137` 8 titik; `TreasureService.luau:116` pilih acak + offset; y=3 vs HRP ±3.5, radius gali 8 (`TreasureConfig.luau:18-22`) terjangkau |
| 9 | Jarak interaksi | PASS (kode) / NOT TESTED (Play) | `StealDistance=15` (`Config.luau:22`), cek `+10` toleransi (`StealSystem.luau:72`); gali radius 8; kompas hanya jarak kasar+arah (`TreasureService.luau:191-222`) |
| 10 | Jumlah part & loop server | PASS | Statis ±39 part (1 tanah + 8 plot + 8 pole + 1 plaza + 1 shop + 1 spawn + 3 rambu + 16 pohon); crop maks 8 pemain × 8 slot = 64 bola + label. Loop: income 1 dtk (`Main.server.luau:284`), visual 5 dtk (`:401`) — keduanya milik Main, tidak ditambah loop baru |
| 11 | Deterministik / antar-pemain tidak ganggu plot lain | PASS | Plot & pohon & rambu posisi sudut tetap; visual per-Owner; crop grid urut kunci slot stabil (`PlotVisuals.luau:44-53`); steal butuh slot bebas + uid milik victim (`Main.server.luau:340-376`) |
| 12 | Visual tidak yield/hang | PASS (diperbaiki) | AssetMap di-cache via `FindFirstChild` sekali (`PlotVisuals.luau:18-34`); sebelumnya `WaitForChild` tiap refresh bisa menahan thread visual 5-detik |

## 3. Bug Dunia Ditemukan & Diperbaiki

1. **`PlotVisuals.Refresh` memanggil `WaitForChild("AssetMap")` tiap refresh** (tiap 5 dtk per
   pemain, `PlotVisuals.luau` lama `:21-24`). Bila `AssetMap` belum tereplikasi, thread visual
   yield tanpa batas. → Diganti cache modul sekali pakai `FindFirstChild` (`:18-34`).
2. **Urutan crop acak tiap refresh**: `for _, slot in slots` (pairs atas dictionary) membuat
   posisi grid 4×2 meloncat setiap 5 detik. → Kunci slot di-sort dulu (`:44-53`).
3. **`Trees()` early-return bila folder ada** (`MapBuilder.luau` lama `:112-115`): folder parsial
   (mis. 3 pohon terhapus) tidak pernah diperbaiki. → Validasi per-nama (`:126-163`).
4. **`Sign()` return bila tiang ada** (lama `:147-149`): GUI yang terhapus tidak dibangun ulang.
   → Cek `FindFirstChildOfClass("BillboardGui")` dan bangun ulang bila hilang (`:180-182`).
5. **Properti tidak ditegakkan saat rebuild**: Ground/Plaza/Shop/Spawn/plot/pole hanya di-set
   saat pembuatan; bila properti diubah manual/eksploit, rebuild tidak memperbaikinya.
   → Semua properti (Anchored/CanCollide/posisi/ukuran/Neutral) ditegakkan tiap `Build()`.
6. **Label crop sulit dibaca** (hitam polos di atas bola warna). → Putih/GothamBold + stroke
   hitam; matang kuning-keemasan (`PlotVisuals.luau:96-103`). Nol biaya runtime tambahan.

## 4. Game-Feel Ringan (tanpa loop/partikel/suara baru)

- Matang vs mentah: ukuran 3 vs 1.5 + opak vs 50% transparan (lama) + material
  `SmoothPlastic` vs `Grass` dan permukaan stud dihaluskan (baru, statis, gratis).
- Label `✅`/`🌱` + mutasi (`[Gold]` dsb.) dipertahankan; keterbacaan dinaikkan via stroke.
- Feedback event (steal_ok, treasure_found, tick) tetap lewat `UpdateHud` dari Main —
  tidak diduplikasi di layer dunia agar tidak ada spam/clash antar-agen.

## 5. Sisa Risiko (butuh Play test di Studio)

- Spawn fisik: jatuh 2 stud dari SpawnLocation ke plaza, dan apakah `SpawnLocation`
  berkonflik dengan plot saat server penuh (8 pemain = 8 plot pas; pemain ke-9 tak dapat plot
  tapi tetap main — by design `ServerSize = 8`).
- Safezone `StealSystem.inSafeZone`: radius = `Size.Magnitude/2` ≈ 21 stud untuk plaza
  30×1×30 — sedikit lebih besar dari setengah diagonal (±21.2); karakter di tepi luar plaza
  masih terhitung safe. Terima atau kecikan? NOT TESTED.
- Shop balok solid 12×6×12: pemain tak bisa masuk; pastikan UI toko tidak butuh proximity
  prompt di dalam balok. NOT TESTED.
- Treasure y=3 + offset ±12 bisa mendarat di dalam balok Shop/plaza tepi — radius gali 8
  masih mencakup, tapi visual titik tidak ada (by design rahasia). NOT TESTED.

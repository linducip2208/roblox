# PERFORMANCE & OPTIMIZATION AUDIT — Steal a Kebun

> Status: **NOT TESTED** — tidak ada runtime profiling dalam audit ini.
> Semua klaim dampak bersifat kualitatif (CPU/mem/network) berdasarkan inspeksi kode,
> bukan angka MicroProfiler. Angka hanya boleh diisi setelah uji Studio di bawah.
> Repo: Rojo/Luau. Audit read-only terhadap `src/Server`, `src/Client` (+ `src/Shared`
> seperlunya untuk jalur panas). Tidak ada kode diubah.

## Ringkasan eksekutif

- Beban berat saat ini TERKONSENTRASI di 3 titik: (1) loop income 1 Hz di
  `Main.server.luau`, (2) refresh visual 5 detik yang menghancurkan + membuat ulang
  semua part Crop, (3) `FindFirstChild(..., true)` rekursif di jalur steal.
- Skala target kecil (ServerSize 8, MaxSlots 8, 10 riddle) sehingga tidak ada
  temuan kritis O(n²) yang mematikan. Semua temuan AMAN adalah pemangkasan
  limbah kecil-sedang; temuan RISIKO butuh keputusan desain (UX/safety vs cost).
- Tidak ditemukan `while true do` tanpa yield, tidak ada Heartbeat per-frame,
  tidak ada RemoteFunction yang dipanggil per-frame dari client.

## Temuan AMAN (bisa diterapkan otomatis, tanpa ubah perilaku)

| # | Lokasi | Masalah | Dampak | Perbaikan (snippet) |
|---|--------|---------|--------|---------------------|
| A1 | `src/Server/Main.server.luau:401-428` | Loop visual 5 dtk memanggil `plots:GetChildren()` **per pemain** (8x scan redundan) lalu `Refresh` per plot milik pemain | CPU server (scan + pcall berulang), yield 5 dtk × N | Hoist satu kali scan + petakan Owner→plot:<br>`local plots = workspace:FindFirstChild("Plots")`<br>`if plots then local byOwner = {} for _, plot in plots:GetChildren() do local o = plot:FindFirstChild("Owner") if o then byOwner[o.Value] = plot end end for _, p in Players:GetPlayers() do ... Refresh(byOwner[tostring(p.UserId)], ...) end end` |
| A2 | `src/Server/PlotVisuals.luau:21-24` | `require(...:WaitForChild("AssetMap"))` di dalam **setiap** `Refresh` (dipanggil tiap 5 dtk per pemain). `WaitForChild` bisa yield lama | CPU + yield di jalur panas; stall loop visual | Cache sekali di atas modul:<br>`local AssetMapOk, AssetMap = pcall(require, game.ReplicatedStorage.Shared:WaitForChild("AssetMap", 5))`<br>lalu pakai `if AssetMapOk then ... end` di `Refresh` |
| A3 | `src/Server/StealSystem.luau:27-31` | `inSafeZone` memakai `FindFirstChild(name, true)` **rekursif seluruh workspace** di tiap `CanSteal` (dipanggil tiap tick untuk tiap channel aktif + tiap RequestSteal) | CPU hot-path steal; memburuk seiring map membesar | Cache referensi sekali:<br>`local safeZonePart do local function bind() safeZonePart = workspace:FindFirstChild(Config.SafeZoneName, true) end bind() workspace.DescendantAdded:Connect(function(d) if d.Name == Config.SafeZoneName then safeZonePart = d end end) end`<br>cek `safeZonePart` langsung, tanpa scan |
| A4 | `src/Server/Main.server.luau:302-309` | `pcall(EventManager.Multiplier())` dihitung **per pemain per tick** padahal hasilnya sama untuk semua pemain dalam satu tick | CPU (pcall + `os.time` × N per detik) | Hoist ke luar loop pemain:<br>`local mult = 1 local okM, m = pcall(EventManager.Multiplier) if okM and type(m)=="number" then mult = m end for _, p in ... do local raw = PlotManager.TickIncome(profile) if mult > 1 then raw = math.floor(raw*mult) end ... end` |
| A5 | `src/Client/Sound.client.luau:19-23` | `beep()` membuat `Sound` lalu `Parent = workspace` — part suara **direplikasi ke server + semua client** padahal hanya untuk pendengar lokal | Network + replikasi sia-sia per bunyi | Parent lokal saja:<br>`s.Parent = player:WaitForChild("PlayerGui")`<br>(atau `game:GetService("SoundService")`) |
| A6 | `src/Client/Hud.client.luau:78-84` | `TweenService:Create` × 2 + `task.delay` **setiap tick 1 Hz** saat cash naik — churn tween/GC tiap detik per client | CPU/GC client, layout thrash | Pulse hanya untuk event besar:<br>`elseif data.type=="steal_ok" or data.type=="treasure_found" then pulse()`<br>atau batasi: `if cash - lastCash >= 1000 then pulse() end` |
| A7 | `src/Client/InventoryUI.client.luau:170-178` | Loop 5 dtk menulis ulang `rec.b.Text` untuk 4 tombol **meski `ids` tidak berubah** | Render UI sia-sia (kecil) | Tulis ulang hanya saat berubah:<br>`local lastSig = "" ... local sig = table.concat({ids.gpDouble,ids.gpVip,ids.pLuck,ids.pUnlock},"\|") if sig ~= lastSig then lastSig = sig for ... rec.b.Text = ... end end` |
| A8 | `src/Server/Leaderboard.luau:22-31` | Satu `task.spawn` + `while player.Parent` **per pemain** (N thread polling 2 dtk) | Thread + bangun berlebih; N tumbuh per join | Lipat ke loop tick utama `Main` (sudah per detik per pemain):<br>`-- di Main tick: local ls = p:FindFirstChild("leaderstats") if ls then ls.Cash.Value = MoneyService.Get(p) ... end`<br>hapus thread per-pemain |
| A9 | `src/Client/StealPrompt.client.luau:46-51` | `ChildAdded` memakai `task.wait(1)` arbitrer sebelum hook — Hook terlambat 1 dtk untuk plot baru; pola rapuh | UX (prompt muncul telat) | Hook langsung tanpa tunggu:<br>`plotsFolder.ChildAdded:Connect(function(c) if c:IsA("BasePart") then hookPlot(c) end end)`<br>(`hookPlot` sudah idempoten via cek `StealPrompt`) |
| A10 | `src/Server/SaveSystem.luau:86-99` | Setiap `Save` menghitung **seluruh** `receipts` (`for _ in d.receipts`) sebelum memutuskan prune; Save dipanggil dari banyak jalur (buy/daily/dig/steal/autosave) | CPU per Save saat tabel besar | Early-out:<br>`local count = 0 for _ in d.receipts do count += 1 if count > 200 then break end end` |

## Temuan RISIKO (butuh keputusan desain — JANGAN otomatis)

| # | Lokasi | Masalah | Dampak | Opsi + trade-off |
|---|--------|---------|--------|------------------|
| R1 | `src/Server/Main.server.luau:387-394` | `UpdateHud:FireClient("tick")` **1 Hz ke setiap pemain walau cash tidak berubah** (tanaman belum grown = payload sama tiap detik) | Network downstream N msg/dtk selalu | Opsi: kirim hanya bila `cash/income/locked/level` berubah, atau turunkan ke 2 dtk. Trade-off: kehalusan angka HUD vs bandwidth. Keputusan UX. |
| R2 | `src/Server/Analytics.luau:9-19` | Tiap event (`Buy` = 2 writes, join/steal/rebirth/riddle) = `task.spawn` + `DataStore:UpdateAsync` langsung. Burst pembelian = burst write DataStore | Throttle DataStore, gagal tulis diam-diam (pcall) | Opsi: antrean in-memory + flush agregat per 60 dtk (satu write per key per flush). Trade-off: akurasi real-time vs ketahanan throttle. |
| R3 | `src/Client/ShopUI.client.luau:222-227` (10 dtk) + `src/Client/InventoryUI.client.luau:195-200` (15 dtk) | Polling `RemoteFunction` berkala dari tiap client (`RequestStock`, `RequestInventory`) | Network + handler server; skala N × frekuensi | Opsi: server push (`FireClient`/`FireAllClients`) hanya saat restock/inventory berubah. Trade-off: kompleksitas state server vs polling sederhana yang sekarang. |
| R4 | `src/Server/SaveSystem.luau:396-458` | Tiap `Save` diawali `VerifyLock` (`MemoryStore:GetAsync`) lalu `UpdateAsync` DataStore — 2 round-trip per save; save dipanggil sering (lihat A10) | Latensi + biaya MemoryStore/DataStore | Opsi: lewati `VerifyLock` bila lock diverifikasi < X dtk lalu (cache `lastVerifiedAt`). Trade-off: safety fail-closed melemah vs biaya. Butuh keputusan keamanan data. |
| R5 | `src/Server/PlotVisuals.luau:14-20` | `Refresh` menghancurkan **semua** `Crop` + membuat ulang Part/Decal/BillboardGui/TextLabel tiap 5 dtk per plot (s.d. 64 set instance) | Replikasi + GC + render client; spike tiap 5 dtk | Opsi: incremental — pakai ulang part, update hanya `Size/Color/Text` bila `grown` berubah; tambah/hapus hanya bila jumlah slot berubah. Trade-off: rewrite modul visual vs churn saat ini. Perlu uji visual. |

## Catatan non-temuan (sengaja TIDAK diusulkan)

- Loop income 1 Hz (`Main.server.luau:284`) + autosave stagger 0,5 dtk
  (`SaveSystem.luau:461`), heartbeat lock 60 dtk (`SaveSystem.luau:236`),
  restock 300 dtk (`ShopRotation.luau:70`), event-auto 60 dtk
  (`EventManager.luau:89`) — semua frekuensi wajar untuk 8 pemain, tidak diusulkan diubah.
- `RequestSteal` scan max 8 slot (`Main.server.luau:250`) dan `nearestSpot`
  (`TreasureService.luau:174`) — O kecil, bukan masalah.
- `PlayerAdded → p.Chatted:Connect` (`Main.server.luau:431`) dan
  `Tutorial` listener (`Tutorial.client.luau:33`) — satu koneksi per sesi,
  dibersihkan saat objek pemain/GUI dihancurkan; bukan kebocoran berarti.

## Rencana uji performa 1 / 2 / 8 pemain (Studio only — NOT TESTED)

> Semua langkah di bawah memakai Play-test Studio (F5) + bot pemain virtual.
> Tidak ada yang sudah dijalankan dalam audit ini.

### Persiapan (sekali)

1. Buka place di Roblox Studio → tab `View` → aktifkan `MicroProfiler`,
   `Memory`, `Network` (Client+Server), `Output`.
2. Pastikan `Config.ServerSize = 8`, `IncomeTick = 1` (kondisi produksi).
3. Jalankan Play-test: `Test` → `Clients and Servers` → `Players = 1` → `Start`.

### Uji 1 pemain (baseline fungsional)

1. Start 1 pemain. Di Server console jalankan:
   `require(game.ServerScriptService.Server.EventManager).Start(1, "meteor")`
   (paksa multiplier x4 agar jalur `mult > 1` aktif).
2. Beli 8 slot penuh item termurah, catat di MicroProfiler: frame time server,
   `UpdateHud` bytes/dtk (panel Network → cari `UpdateHud`).
3. Tunggu 60 dtk, amati `Refresh` visual: hitung instance `Crop` di Explorer
   (harusnya 8, stabil — bukan bertambah = tidak bocor).
4. Catat baseline: server frame ms, client frame ms, memori Lua server.

### Uji 2 pemain (jalur steal + channel)

1. `Players = 2`. Pemain A tanam s.d. grown (atau set `plantedAt` mundur via
   Server console untuk percepat), pemain B tahan E di plot A 3 dtk.
2. Selama channel berjalan, amati MicroProfiler server pada frame tick 1 Hz:
   pastikan tidak ada spike `inSafeZone` (itulah yang diperbaiki A3).
3. Verifikasi fungsional: steal sukses 1x, `itemLocks` lepas (coba steal item
   sama oleh pemain yang sama langsung = harus `cooldown`, bukan macet).

### Uji 8 pemain (beban penuh)

1. `Players = 8`. Isi tiap pemain ≥ 4 slot (bisa via Server console loop
   `PlotManager.Plant` agar cepat).
2. Jalankan 5 menit. Catat tiap 60 dtk: server heartbeat ms (MicroProfiler),
   total `UpdateHud` KB/dtk (Network), jumlah `Crop` instance
   (harusnya 8 pemain × slot terisi, stabil di tiap refresh 5 dtk).
3. Paksa autosave: di Server console panggil
   `require(game.ServerScriptService.Server.SaveSystem)` lalu `Save` tiap pemain;
   pastikan tidak ada error `throttled` di Output.
4. Kriteria lulus awal (keputusan orkestrator, bukan klaim audit ini):
   server frametime tidak naik > 2x dibanding baseline 1-pemain, tidak ada
   error DataStore/MemoryStore, tidak ada instance `Crop`/`Sound` bocor
   (cek `workspace` + `PlayerGui` setelah stop).

## Saran urutan pengerjaan untuk orkestrator

1. Batch 1 (murni hapus limbah): A2, A3, A4, A5, A9.
2. Batch 2 (sentuh loop/UI): A1, A6, A7, A8, A10.
3. Batch 3 (desain): R1–R5 satu per satu, masing-masing diikuti uji 8-pemain di atas.

## Disposisi orkestrator 9 Nov 2026 (pasca Master 7, tanpa Studio)
- **R1 delta-push HUD: DITERAPKAN.** `Main.server.luau`: snapshot
  `cash|mult|locked|income|level` per pemain, `FireClient("tick")` hanya bila
  berubah + `lastHud` dibersihkan saat `PlayerRemoving`. Display-correct
  (tak ada perubahan = label sudah benar; pulse hanya saat cash naik = pasti terkirim).
  Selene 0/0, StyLua bersih, verify 44/0/2/6 tetap hijau.
- **R2 antrean Analytics: DITERAPKAN.** `Analytics.luau`: `bump()` kini agregat
  di memori, 1 thread flush/60 detik via `UpdateAsync` add (aman konkuren antar
  server; gagal = antre lagi). Jendela hilang ≤60 detik saat crash — dapat diterima
  untuk analitik; data pemain tetap lewat `SaveSystem` langsung. API 6 fungsi utuh.
- **R3 polling→push Shop/Inventory: DITOLAK (sementara).** Polling 10/15 detik ×
  8 pemain ≈ 1 req/detik — sepele; push butuh remote baru + logika invalidation
  yang tak bisa diverifikasi tanpa Studio. Rasio risiko/manfaat buruk.
- **R4 cache VerifyLock: DITOLAK (keamanan).** Melemahkan fail-closed fencing demi
  latensi — tidak sepadan. Biaya 2 round-trip per save diterima.
- **R5 refresh PlotVisuals inkremental: DITUNDA.** Refresh 5-detik sudah murah
  (≤8 plot); diff inkremental berisiko desync visual yang tak terdeteksi semua
  gate tanpa Studio. Kerjakan setelah uji visual 8-pemain.

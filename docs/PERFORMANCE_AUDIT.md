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

## Addendum Agen 6 — audit ulang pasca-Master 7 (9 Nov 2026, read-only, tanpa runtime)

> Tanpa runtime = tidak ada angka pengukuran. Semua dampak di bawah kualitatif.
> Verifikasi klaim Master 7 dilakukan per path:line. Temuan baru diberi ID B1..;
> ID A/R lama dirujuk statusnya (diterapkan / masih terbuka).

### Verifikasi klaim Master 7 (perilaku tidak rusak)

- **lastHud delta-push — OK, behavior-preserving.** `Main.server.luau:412-431`:
  snapshot `cash|mult|locked|gained|level`, kirim hanya bila berubah;
  pembersihan `Main.server.luau:785-791` (`lastPos/lastHud/rateLast/lastAdminCmd`
  = nil saat `PlayerRemoving`). Display-correct: tak ada perubahan = label sudah
  benar. Catatan: `gained` ikut snapshot sehingga tick dengan income>0 selalu
  push 1 Hz saat tanaman grown — itu benar (angka memang berubah tiap detik).
- **flush Analytics — OK.** `Analytics.luau:11-46`: `bump()` agregat per kunci
  hari, 1 thread 60 dtk, `UpdateAsync` add (konkuren-aman), gagal = antre lagi.
  API 6 fungsi utuh. Catatan: `BindToClose` tidak flush `pending` (rugi <=60 dtk
  saat shutdown, dinyatakan dapat diterima) dan `pending` tumbuh bila DataStore
  gagal terus — lihat B4 (P2).
- **peta Owner 1-pass — OK.** `Main.server.luau:442-453`: satu
  `plots:GetChildren()` per 5 dtk + peta `byOwner`, rebuilt tiap tick (tanpa
  cache basi). `FindFirstChild("Owner")` per plot (<=8) sepele. `assignPlot` /
  `releasePlot` (`Main.server.luau:697-730`) tetap scan per join/leave — wajar.
- **early-break receipts — OK, identik perilaku.** `SaveSystem.luau:91-98`:
  break saat count > 200, keputusan prune sama persis dengan hitung penuh.
- **suara ke PlayerGui — OK dengan satu celah kecil.** `Sound.client.luau:22-24`:
  `s.Parent = pg or workspace` — fallback `workspace` saat PlayerGui sesaat
  hilang (jendela respawn) masih mereplikasi; sepele. Celah nyata adalah
  kebocoran `Sound` bila `Ended` tak pernah fire — lihat B3 (P2).

### Tabel per-UserId: dibersihkan / TIDAK saat PlayerRemoving

| Tabel | Dibersihkan? | Bukti |
|---|---|---|
| `StealSystem` locks/cooldowns/channels + itemLocks miliknya | YA | `StealSystem.luau:116-124` |
| `MoneyService` balances/multipliers | YA | `MoneyService.luau:90-93` |
| `GamepassHandler` luckUntil | YA | `GamepassHandler.luau:85-87` |
| `TreasureService` spots/lastAttempt/lastDig/lastPing | YA | `TreasureService.luau:275-280` |
| `Main` lastPos/lastHud/rateLast/lastAdminCmd | YA | `Main.server.luau:785-791` |
| `SaveSystem` cache/loadedOk/sessionToken/sessionGen | YA (parsial) | `SaveSystem.luau:583-591` |
| **`SaveSystem` savedOnLeave — TIDAK (bocor + bug rejoin)** | **TIDAK -> B1** | `SaveSystem.luau:34,574-591`; `DropCache` (`:235-242`) membersihkannya tapi jalur leave normal tidak lewat `DropCache` |

### Temuan baru (B) — dengan bukti kode, bukan tebakan

| # | Sev | Lokasi | Masalah | Bukti |
|---|---|--------|---------|-------|
| B1 | **P0/P1** | `SaveSystem.luau:34,574-591` | `savedOnLeave[uid]` diset `true` saat leave tapi **tak pernah dibersihkan** (jalur leave tidak lewat `DropCache`). Akibat ganda: (a) tumbuh 1 entri per joiner unik selama umur server (bocor lambat); (b) **pemain yang rejoin server yang sama tidak pernah di-autosave lagi** karena loop autosave `if not savedOnLeave` (`:574-577`) melewatkannya permanen. | Baca `:583-591` vs `:235-242` vs `:574-579`; `ClaimSession` (`:160-196`) tidak mereset flag |
| B2 | P1 | `StealSystem.luau:17-32` + `Main.server.luau:358` | A3 **belum diterapkan**: `inSafeZone` = `workspace:FindFirstChild(name, true)` **rekursif seluruh workspace** tiap `CanSteal`, dan `CanSteal` dipanggil **tiap tick 1 Hz per channel aktif**. Membesar seiring map. | `StealSystem.luau:27`; pemanggil `Main.server.luau:358` di loop tick |
| B3 | P1/P2 | `Sound.client.luau:15-29` + `Hud.client.luau:115-129` | (a) Tiap `beep` membuat `Sound` + koneksi `Ended`; bila aset gagal / `Ended` tak fire, instance **tak pernah Destroy** -> akumulasi di PlayerGui. (b) A6 **belum diterapkan**: pulse `TweenService:Create` x2 + `task.delay` **tiap tick saat cash naik** (= tiap detik saat panen) di tiap client; restore `Size = base` memakai ukuran basi bila `fitHud` resize di tengah tween. | `Sound.client.luau:19-28`; `Hud.client.luau:119-128` |
| B4 | P2 | `Analytics.luau:25-46` | `pending` tumbuh tak terbatas bila `UpdateAsync` gagal terus (re-antre + event baru). Maks ~7 kunci, kecil — cukup batasi. | `:28-43` |
| B5 | P2 | `Leaderboard.luau:21-32` | A8 **belum diterapkan**: 1 thread + 2 `require` + polling 2 dtk **per pemain**. Tak bocor (`while player.Parent` keluar saat leave) tapi bangun sia-sia x N. | `:21-32` |
| B6 | P2 | `StealPrompt.client.luau:46-51` + `InventoryUI.client.luau:179-190` | A9 & A7 **belum diterapkan**: `ChildAdded` menahan thread `task.wait(1)` per plot baru (prompt telat 1 dtk); loop 5 dtk cek teks tombol tidak sejajar refresh `ids` 15 dtk. Fungsional benar, hanya limbah/UX kecil. | path:line sesuai |
| B7 | P2 | `Main.server.luau:333-345,413-415` | `MoneyService.Get` dipanggil 3-4x per pemain per tick. Sepele (table lookup) — satukan bila menyentuh loop lagi. Bukan prioritas. | `:340-345,413` |

R5 (refresh visual destroy-all tiap 5 dtk, `PlotVisuals.luau:36-42`) tetap
penyumbang churn terbesar (<=8 plot x ~4 instance tiap 5 dtk + replikasi) namun
**tetap DITUNDA** — diff inkremental tanpa uji visual Studio berisiko desync.
R3 (polling Shop 10 dtk / Inventory 15 dtk) tetap **DITOLAK sementara** —
beban ~1,3 req/dtk @8 pemain, read-only + rate-limit 2 dtk.

### Patch AMAN yang diusulkan (behavior-preserving, tanpa korbankan keamanan)

1. **B1 — reset `savedOnLeave` saat sesi baru (wajib).** `SaveSystem.luau`
   (`ClaimSession`, setelah token lolos): `savedOnLeave[player.UserId] = nil`.
   Satu baris, memperbaiki autosave-rejoin + menghentikan bocor lambat.
2. **B2 — cache SafeZone (A3).** Di `StealSystem.luau` tambah
   `local safeZonePart: BasePart? = nil` + binder sekali +
   `workspace.DescendantAdded` untuk nama `Config.SafeZoneName`;
   `inSafeZone` cek jarak ke `safeZonePart` saja, fallback `false` bila nil.
   Aturan jarak tak berubah.
3. **B3a — pulse HUD hanya untuk peristiwa besar (A6).** Di
   `Hud.client.luau:119-128`, pulse hanya bila
   `data.type == "steal_ok" or data.type == "treasure_found"`, atau ambang
   `cash - lastCash >= 1000`; tick income biasa hanya update teks.
4. **B3b — pengaman `Sound`.** Di `Sound.client.luau:26-28`, tambah
   `task.delay(5, function() if s and s.Parent then s:Destroy() end end)`
   sebagai jaring bila `Ended` tak fire. Perilaku bunyi tak berubah.
5. **B4 — batasi `pending`.** Di `Analytics.luau`, bila ukuran `pending` > 500
   maka drop event baru (analitik boleh hilang; data pemain tidak lewat sini).
6. **B5 — lipat leaderboard ke tick Main (A8).** Hapus thread
   `Leaderboard.luau:21-32`; di loop tick `Main.server.luau` tulis
   `leaderstats.Cash/Rebirths` bila ada (display-only, 1 Hz vs 2 Hz).
7. **B6 — hapus `task.wait(1)` (A9).** `StealPrompt.client.luau:46-51`:
   hook langsung di `ChildAdded` (`hookPlot` sudah idempoten).

### Checklist profiling 1 / 2 / 8 pemain (dapat diulang di Studio)

> Jalankan SETELAH patch B1; ulangi penuh bila R5 dikerjakan. Konsol server:
> View -> MicroProfiler + Memory + Network + Output.
> `Config.ServerSize = 8`, `IncomeTick = 1`. Isi angka aktual, jangan klaim kosong.

| # | Skenario | Langkah | Yang dicatat | Lulus bila |
|---|---|----------|--------------|------------|
| C1 | 1 pemain baseline | Play 1 pemain -> tanam 8 slot -> paksa event `EventManager.Start(1,"meteor")` -> 60 dtk | server frame ms, client frame ms, Lua memori server, `UpdateHud` byte/dtk, jumlah `Crop` (stabil, tak tumbuh) | `Crop` stabil; nol error DataStore/MemoryStore |
| C2 | 2 pemain steal | 2 pemain; A tanam s.d. grown; B tahan E 3 dtk di plot A selama channel | spike `inSafeZone`/tick di MicroProfiler; steal 1x sukses; lock kedua langsung = `cooldown` (tak macet) | channel selesai/batal bersih; tak ada item terkunci permanen |
| C3 | 8 pemain beban | 8 pemain, tiap >=4 slot; jalan 5 mnt; paksa `Save` tiap pemain | heartbeat ms tiap 60 dtk, `UpdateHud` KB/dtk, `Crop` total stabil tiap refresh 5 dtk, error `throttled` | frametime < 2x baseline C1; nol `throttled`; nol `Sound`/`Crop` bocor pasca-stop |
| C4 | rejoin (khusus B1) | 1 pemain join -> leave -> **rejoin server sama** -> tunggu 2x `AutosaveInterval` | Output: ada save rejoin (tak ada `skip save`); autosave rejoin jalan | autosave rejoin jalan |

### Disposisi R3 / R5 yang masih terbuka (Agen 6)

- **R3 polling ke push: tetap DITOLAK sementara.** Syarat buka ulang: kebutuhan
  fitur realtime + slot uji Studio C3 hijau.
- **R5 visual inkremental: tetap DITUNDA.** Syarat kerjakan: uji C3 hijau +
  uji visual 8-pemain khusus (bandingkan `Size/Color/Text` per refresh,
  pastikan tanpa flicker/hilang).

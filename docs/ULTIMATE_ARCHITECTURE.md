# ULTIMATE ARCHITECTURE — Steal a Kebun (Agen 1, Principal Architect)

Tanggal: 2026-11-09. Sumber: baca penuh 31 modul `src/` + `default.project.json`, `selene.toml`, `stylua.toml`, `aftman.toml`, `.gitignore`.
Perintah: READ-ONLY terhadap `src/` dan `tools/` — tidak ada file src/tools yang diubah.

## 0. Konfigurasi build/lint (terverifikasi dari file)

- `default.project.json:1-37` — Rojo: `ReplicatedStorage.Shared ← src/Shared`, `ServerScriptService.Server ← src/Server`,
  `StarterPlayerScripts.Client ← src/Client`, `Workspace.Plots` = Folder kosong, `ReplicatedStorage.Remotes` = Folder kosong
  (diisi saat runtime oleh `Main.server.luau:22-36` via `getOrCreate`). Tidak ada instance statis lain; seluruh map dibuat prosedural.
- `selene.toml:1-7` — `std = "roblox"`, `exclude = ["tools/*"]`, lint `roblox_manual_fromscale_or_fromoffset = allow`
  (offset piksel di UI disengaja untuk mobile kecil).
- `stylua.toml:1-5` — `column_width=120`, `line_endings=Windows`, `indent_type=Tabs`, `quote_style=AutoPreferDouble`.
- `aftman.toml:1-4` — `rojo 7.4.4`, `selene 0.27.1`, `stylua 2.0.2`.
- `.gitignore:1-13` — mengabaikan `.rojo/`, `game.rbxlx` (build artefact, benar diabaikan), `tools/rojo|selene|stylua/*`.
  Catatan: `game.rbxlx` ada di working tree tapi diabaikan git — rebuild dari Rojo adalah sumber kebenaran, bukan file itu.

## 1. Inventaris modul (31 = 8 Shared + 16 Server + 7 Client, cocok dengan MASTER6)

Shared (`ReplicatedStorage.Shared`, direplikasi ke client — JANGAN taruh rahasia di sini):
1. `src/Shared/Config.luau` — balancing tunggal (ServerSize 8, MaxSlots 8, lock/rebirth, income cap, SafeZoneName, Gamepass/Product ID, Events, Mutations, AdminUserIds kosong).
2. `src/Shared/Items.luau` — 22 definisi (20 + 2 EventOnly: `kopi_hujan`, `payung_raksasa`), `ById` lookup.
3. `src/Shared/AssetMap.luau` — semua value `""` (belum upload); `Get()` return nil bila kosong — kontrak "tanpa kotak rusak" bergantung pada ini.
4. `src/Shared/ShopRotation.luau` — stok + restock 5 mnt + `task.spawn` auto-restock saat modul di-require.
5. `src/Shared/TreasureConfig.luau` — 10 riddle publik (Q/Choices/Hint/Zone/Reward) TANPA jawaban; SpawnPoints + RandomOffset.
6. `src/Shared/UiTheme.luau` — satu-satunya sumber gaya (palet, Rarity, DecoratePanel/Button/Title/Label, Hover client-only).
7. `src/Shared/UiPanels.luau` — registry visibilitas panel eksklusif per-client (Register/SetVisible/Toggle/Unregister/Names).
8. `src/Shared/UiIcons.luau` — `Attach()` hanya bila `AssetMap.Get` non-nil.

Server (`ServerScriptService.Server`):
9. `src/Server/Main.server.luau` — wiring: cipta 16 remote, semua `OnServerInvoke/Event`, income loop, steal-channel loop, visual refresh, PlayerAdded/Removing, ProcessReceipt, admin `;event`.
10. `src/Server/SaveSystem.luau` — session lock (MemoryStore) + envelope DataStore + validasi + offline growth + autosave + BindToClose.
11. `src/Server/MoneyService.luau` — satu-satunya penulis cash (`balances[uid]`), multiplier, Add/Spend/Set.
12. `src/Server/PlotManager.luau` — slot tanam (`slots["1".."8"]`), Plant/IsGrown/TickIncome/AddStolenSlot.
13. `src/Server/StealSystem.luau` — locks/cooldowns/channels/itemLocks in-memory, CanSteal/RequestSteal/PollChannel/ClearChannel.
14. `src/Server/TreasureService.luau` — SERVER-ONLY: jawab, spot per-riddle in-memory + persist `profile.treasure.spots`.
15. `src/Server/TreasureAnswers.luau` — `R1..R10 → index benar`. Tidak boleh di-require client/Shared.
16. `src/Server/InventoryService.luau` — Ensure/GiveShovel/GiveCompass/SpendKeys atas `profile.treasure`.
17. `src/Server/DailyReward.luau` — 7 hadiah, kunci `%Y%j`, streak reset bila skip hari.
18. `src/Server/RedeemCode.luau` — 3 kode hardcode sekali-pakai per pemain (`profile.redeemed`).
19. `src/Server/EventManager.luau` — Active/EndsAt/CurrentKey + gen-token anti task basi + auto Sabtu 12:00 UTC + `EventState:FireAllClients`.
20. `src/Server/GamepassHandler.luau` — Luck (memori + `profile.luckUntil`), OnProductBought idempoten via receipts, DoubleMoney refresh.
21. `src/Server/MapBuilder.luau` — bangun Ground/Plots_1..8/TradePlaza/Shop/Spawn/Rambu/Trees, idempoten per-nama.
22. `src/Server/PlotVisuals.luau` — Refresh Crop per rarity + Decal bila AssetMap terisi + BillboardGui nama.
23. `src/Server/Leaderboard.luau` — leaderstats Cash/Rebirths, refresh 2 dtk dari MoneyService/SaveSystem.
24. `src/Server/Analytics.luau` — bump harian fire-and-forget ke `KebunAnalytics_v1`.

Client (`StarterPlayerScripts.Client`):
25. `src/Client/ShopUI.client.luau` — panel shop + Lock/Rebirth/Daily/Redeem + stok/event; panel `shop`.
26. `src/Client/InventoryUI.client.luau` — panel profil + tombol gamepass/devproduct dinamis + mute; panel `profile`.
27. `src/Client/Hud.client.luau` — cash/income/lock/mult/level + nav Toko/Harta/Profil; konsumen `UpdateHud`.
28. `src/Client/StealPrompt.client.luau` — ProximityPrompt per Plot (hold 3 dtk, jarak 15) → `RequestSteal(victimId, "")`.
29. `src/Client/TreasureUI.client.luau` — riddle/hint/kompas/gali/beli alat; panel `treasure`.
30. `src/Client/Sound.client.luau` — beep bawaan `rbxasset://` untuk steal/stolen/welcome/event; mute via `InventoryGui:GetAttribute("Muted")`.
31. `src/Client/Tutorial.client.luau` — banner 3 langkah; selesai bila `tick.cash > 500`, hancur 10 dtk kemudian.

Verifikasi klaim MASTER5/MASTER6 dari sumber aktual:
- MASTER6 (`docs/MASTER6_AUDIT.md:3-6`) benar: 8/16/7 = 31. MASTER5 (`docs/MASTER5_AUDIT.md:3`) menulis "Shared 10 / Server 15 / TOTAL 32" — salah hitung, dikoreksi MASTER6. Terkonfirmasi lewat glob (8 Shared, 16 Server termasuk Main, 7 Client).
- Klaim "0 TODO" — terkonfirmasi: grep `TODO|FIXME|XXX|HACK` di `src/` = 0 hit (hanya komentar biasa + 1 contoh console di `EventManager.luau:101`).
- Klaim "tidak ada Asset ID karangan" — terkonfirmasi: seluruh `AssetMap.luau:5-111` = `""`, `Config.luau:29-36` Gamepass/Product = 0, tidak ada `rbxassetid://` / angka ID di `src/` selain `rbxasset://sounds/*` bawaan di `Sound.client.luau:31-45`.

## 2. Dependency map (modul → modul, via `require`)

```
Config ◄── MoneyService, PlotManager, StealSystem, SaveSystem, GamepassHandler, EventManager, Main
Items ◄── PlotManager, SaveSystem (validasi), ShopRotation, Main
AssetMap ◄── UiIcons ◄── ShopUI, TreasureUI ; InventoryUI (langsung) ; PlotVisuals (pcall-lazy)
TreasureConfig ◄── TreasureService, Main (BuyTool harga)
UiTheme ◄── ShopUI, InventoryUI, Hud, Tutorial, TreasureUI
UiPanels ◄── ShopUI(shop), InventoryUI(profile), Hud(nav), TreasureUI(treasure)
ShopRotation ◄── Main (server saja; tidak ada client yang require — benar)
TreasureAnswers ◄── TreasureService SAJA (server-only, benar)
InventoryService ◄── Main + TreasureService.TryDig (lazy require di TreasureService.luau:253)
MoneyService ◄── Main, SaveSystem.Save (baca balances), Leaderboard (loop), GamepassHandler (lazy)
SaveSystem ◄── Main + GamepassHandler (lazy x3) + Leaderboard (lazy loop)
PlotManager ◄── Main (Plant/FindFreeSlot/IsGrown/TickIncome/AddStolenSlot) + PlotVisuals.Refresh (sebagai argumen)
StealSystem ◄── Main + GamepassHandler.Unlock (lazy)
MapBuilder ◄── Main.Build() saja
Leaderboard / DailyReward / RedeemCode / Analytics / EventManager ◄── Main SAJA (+EventManager ◄── TreasureService.HintFree)
EventManager ──► Analytics.Event (pcall-lazy, EventManager.luau:61-64)
```

Tidak ada `require` client→server-module atau shared→server-module. Tidak ada siklus load-time:
`SaveSystem → MoneyService → Config` satu arah (MoneyService tidak require SaveSystem di top-level).
`GamepassHandler ⇆ SaveSystem` dan `Leaderboard → SaveSystem/MoneyService` semuanya LAZY (`WaitForChild` di dalam fungsi),
bukan top-level — aman dari circular-require crash, tapi lihat §5-R6 (kopling implisit).

## 3. Remote map (client → remote → handler server)

Diciptakan SEKALI di `Main.server.luau:22-36,447-454` via `getOrCreate` (16 remote: 14 RemoteFunction + 2 RemoteEvent).
Semua 16 dikonsumsi client — TIDAK ADA remote tak terpakai:

| # | Remote (kelas) | Client pemanggil | Handler server | Catatan otoritas |
|---|---|---|---|---|
| 1 | RequestBuy (RF) | ShopUI:10,187 `InvokeServer(def.Id)` | Main:140-184 | Server validasi: item ada, bukan Secret, EventOnly⇔EventManager.IsActive, stok (kec. Event), cash cukup, slot bebas; Luck majukan plantedAt 25% |
| 2 | RequestSteal (RF) | StealPrompt:5,33 `InvokeServer(victimId, "")` | Main:221-281 + StealSystem.RequestSteal | uid kosong → server auto-pilih termahal grown; uid isi → server verifikasi milik victim + grown; mulai channel 3 dtk |
| 3 | RequestLock (RE) | ShopUI:11,91 `FireServer()` | Main:187-195 | Rate-limit 1 dtk; LockBase(rebirths, isVip) |
| 4 | RequestRebirth (RF) | ShopUI:12,105 | Main:198-218 | Syarat `RebirthRequirementFor(rebirths)`; reset slots, cash=StartingCash, refresh mult, lock |
| 5 | RequestDaily (RF) | ShopUI:125-126 (lazy WaitForChild) | Main:113-128 | DailyReward.Claim sekali/hari |
| 6 | RequestRedeem (RF) | ShopUI:149-150 (lazy) | Main:93-111 | Upper+strip, ≤32 char, sekali pakai per pemain |
| 7 | RequestRiddle (RF) | TreasureUI:9,189 | Main:500-509 | Kembalikan riddle berikutnya TANPA jawaban/Zone |
| 8 | SubmitAnswer (RF) | TreasureUI:10,85 `InvokeServer(currentId, i)` | Main:511-538 | Floor+clamp 1-4; berurutan; fail>5→lock 60 dtk; beri cash+keys |
| 9 | RequestHint (RF) | TreasureUI:11,122 | Main:540-563 | Cooldown 120 dtk atau bayar 1000; Rush event gratis |
| 10 | CompassPing (RF) | TreasureUI:12,146 | Main:565-574 | Butuh kompas; balas `"<Riddle> <jarak-bulat-10> ke <arah>"\|beepMs` — tidak pernah koordinat |
| 11 | RequestDig (RF) | TreasureUI:13,162 | Main:576-593 | Butuh sekop; radius 8 stud; butuh 1 kunci; level+1; bonus cash |
| 12 | BuyTool (RF) | TreasureUI:14,181-182 (borong shovel+compass) | Main:595-630 | Harga dari TreasureConfig; flag sekali beli |
| 13 | RequestStock (RF) | ShopUI:154,203 | Main:493-498 | `{stock, secs}` read-only, tetap rate-limit 2 dtk |
| 14 | RequestInventory (RF) | InventoryUI:6,112 | Main:456-491 | Profil ringkas + ID produk/gamepass (0 = segera hadir) |
| 15 | UpdateHud (RE, server→client) | Hud:9,74; Sound:4,29; Tutorial:7,33 | Main:330,364-368,387-394,591,702 | tick/welcome/steal_ok/stolen/steal_fail/treasure_found |
| 16 | EventState (RE, server→client) | ShopUI:13,229; Sound:40,43 | EventManager:54,70 (FireAllClients) — `_EventState` di Main:45 hanya ensure-exist | active/endsAt/name/mult |

Rate limit global di `Main.server.luau:57-73` mencakup SEMUA 14 RF + RequestLock (1-5 dtk). Tidak ada remote tanpa rate limit.

## 4. Aliran data profil/uang/item (kontrak)

- Sumber kebenaran profil: `SaveSystem.cache[uid]` (server memori) + DataStore `Config.SaveKey` (`StealKebun_v1`, envelope `{v,session,at,data}`, SCHEMA_VERSION=2).
- Uang: `MoneyService.balances[uid]` adalah penulis; `profile.cash` cermin yang disinkron di income loop (`Main:319`), saat rebirth (`Main:214`), dan `Save()` (`SaveSystem:418-421` membaca balances). Client HANYA menerima via `UpdateHud tick` / `RequestInventory` — tidak pernah mengirim angka uang.
- Item: `profile.slots["1".."8"] = {uid,itemId,mutation,plantedAt}`. Plant (Main→PlotManager.Plant), income (TickIncome × mutation × event-mult × rebirth-mult), steal (pindah atomik slot victim→thief dengan uid BARU di `PlotManager.AddStolenSlot`, `Main:347-373`, rollback slot asli bila gagal).
- Harta: `profile.treasure = {solved,found,spots,keys,hasShovel,hasCompass,level,hintsUsed,fails,lockedUntil,lastHintAt}` (di-Ensure oleh InventoryService tiap PlayerAdded, `Main:693`). Spot aktif ganda: memori `TreasureService.spots[uid][riddleId]` + persist `treasure.spots[riddleId]={x,y,z}` (restore di BindUid).
- Save fail-closed: ClaimSession→Load→main; gagal = kick (`Main:668-704`); Save tolak bila belum loaded/tanpa lock/lock hilang/konflik versi (`SaveSystem:396-458`).

## 5. Temuan berisiko (dengan path:line)

R1 — KEBOCORAN `itemLocks` bila channel ditimpa. `StealSystem.RequestSteal` (`StealSystem.luau:79-91`) menimpa
`channels[thief]` dan mengunci `itemLocks[uid]` baru TANPA melepas kunci lama. Karena cooldown hanya diset saat sukses
(`Main:359`), thief bisa spam RequestSteal → uid pertama terkunci selamanya (sampai thief leave). Perbaikan: lepaskan
`itemLocks` lama di awal RequestSteal / tolak bila channel aktif. (Agen gameplay/steal.)

R2 — `MoneyService.Set` tanpa guard. `MoneyService.luau:80-82` assign mentah (tanpa finite/clamp), melanggar klaim
"satu-satunya penulis cash" yang aman (`Add` punya guard `MoneyService.luau:47-66`). Satu-satunya pemanggil
`Main.server.luau:213-214` (rebirth → StartingCash, nilai konstan aman), jadi risiko AKTIF RENDAH — tapi kontrak untuk
agen lain: JANGAN panggil `Set` dengan nilai dinamis; tambah `finite()`+clamp bila dipakai ulang. (Agen ekonomi/save.)

R3 — Dual source of truth cash. `balances` vs `profile.cash` disinkron manual (tick `Main:319`, rebirth, save).
`RequestBuy` (`Main:164-183`) Spend tanpa update `profile.cash` — benar saat save (Save baca balances), tapi pembaca
`profile.cash` langsung (mis. `RequestInventory:477` memakai `MoneyService.Get` — benar; `welcome` memakai
`profile.cash` — benar karena baru load) harus konsisten memakai `MoneyService.Get`. Kontrak: agen lain DILARANG
membaca/menulis `profile.cash` sebagai otoritas di tengah sesi. (Agen ekonomi/save.)

R4 — Asumsi nama keras tanpa fallback: `Config.SafeZoneName="TradePlaza"` (`Config.luau:24`) dicari rekursif di
`StealSystem.luau:27`; bila dihapus/di-rename, `inSafeZone` diam-diam return false ( proteksi hilang, tanpa warn).
Sama untuk `Workspace.Plots` + pola `^Plot_` + child `Owner` (`Main:405-423,633-666`, `StealPrompt:10-24`,
`MapBuilder:30-69`). Kontrak: MapBuilder adalah SATU-SATUNYA pembuat; agen map dilarang rename tanpa update
`Config` + `StealSystem` + `StealPrompt` + visual loop. Sarankan `warn` bila zone/plots tak ditemukan. (Agen map/steal.)

R5 — Kapasitas 8 pemain rapuh. `MapBuilder.luau:39` loop `1..8` magic-number (duplikat `Config.ServerSize=8`,
`Config.luau:3`); `assignPlot` (`Main:633-647`) diam-diam no-op untuk pemain ke-9 (tanpa kick/pesan); tidak ada assert
ServerSize==jumlah plot. Bila ServerSize diubah, map tidak ikut. Kontrak: ubah keduanya bersamaan; tambah penanganan
pemain-ke-9. (Agen map/lifecycle.)

R6 — Kopling lazy-require tak terlihat di dependency graph statis. `GamepassHandler.luau:13,27,46,58,74-75`,
`Leaderboard.luau:22-23`, `TreasureService.luau:253`, `PlotVisuals.luau:23` me-require di dalam fungsi/loop
(menghindari siklus, benar) tapi menyembunyikan dependensi + `WaitForChild` tiap panggilan (Leaderboard tiap 2 dtk,
HasLuck tiap RequestInventory). Risiko rendah, tapi agen lain JANGAN meniru pola ini untuk dependensi panas;
hoist ke top-level bila tidak ada siklus (InventoryService di TreasureService aman di-top-level — ia tidak punya
dependensi). (Semua agen.)

R7 — `ShopRotation` auto-restock saat di-require (`ShopRotation.luau:70-78`) + memakai `game.ReplicatedStorage.Shared.Items`
langsung (`ShopRotation.luau:2`) padahal modul Shared direplikasi. Saat ini hanya Main (server) yang require — benar.
Tetapi siapapun yang require dari client akan mem-fork stok + loop restock lokal yang menyesatkan. Kontrak: modul ini
SERVER-ONLY secara de-facto; agen lain DILARANG require dari client (baca via RequestStock). Pertimbangkan pindah ke
`src/Server/`. (Agen shop/economy.)

R8 — EventOnly vs stok tidak konsisten. `ShopRotation.Restock` (`ShopRotation.luau:36-54`) mengecualikan Secret tapi
TIDAK mengecualikan EventOnly → item event dapat entri stok phantom yang tidak pernah `Take` (Main:171 skip Take untuk
EventOnly; Main:161 skip cek stok untuk EventOnly). Client menutupinya (`ShopUI:211-216` label [EVENT]). Fungsional
benar, tapi agen shop harus tahu: stok event diabaikan oleh desain. (Agen shop.)

R9 — Time-base campur + state volatile. Lock pakai `os.time` (StealSystem:39), cooldown/channel `os.clock` (64,89);
restart server menghapus locks/cooldowns/channels/itemLocks + `lastPos/rateLast` (Main:721-725) sementara profil persist
→ jendela tanpa proteksi sampai PlayerAdded mengunci ulang 60 dtk (`Main:698`). Bukan bug aktif (rejoin selalu relock),
tapi klaim "anti teleport/speed" hanya sekuat loop 1 dtk + ambang 150 stud (`Main:284-299`) — exploiter moderat masih bisa
bergerak <150 stud/dtk. (Agen steal/security.)

R10 — Duplikat/inkonsistensi kecil (bukan gameplay, untuk agen UI/cleanup):
(a) `InventoryUI.client.luau:68-70` memanggil `UiTheme.Title/Button/Hover(toggleBtn)` kedua kali setelah Register —
redundan, menimpa style `UiTheme.Button(toggleBtn, Bg)` baris 39. (b) `_EventState` (`Main:45`) tidak pernah dibaca
(EventManager membuat sendiri, `EventManager:15-29`) — sisakan sebagai ensure-exist, beri komentar. (c) `PlotManager`
`PlayerRemoving` kosong (`PlotManager.luau:88-90`); `TreasureConfig.luau:127` typo "Plots" di komentar; `ShopRotation`
`rarityWeight` default 1 untuk Secret/Event (`ShopRotation.luau:32`) tapi Secret di-skip — dead branch.
(d) `InventoryUI` statik `statRow` tanpa `LayoutOrder` eksplisit kecuali 10 — urutan bergantung creation order (rapuh bila
agen UI menambah tombol dinamis di tengah; `idBtn` tidak set LayoutOrder).

## 6. Pola otoritas server vs client (ringkas, untuk audit keamanan)

Server-authoritative, BENAR: jawaban (`TreasureAnswers` tak pernah ke client; `PublicRiddle` strip jawaban+Zone —
`TreasureService:65-78`), posisi harta (hanya arah+jarak kasar — `TreasureService:192-222`), harga/stok/event/secret
(`Main:151-163`), grown/ownership (`Main:243-278`), pemindahan item atomik + rollback (`Main:347-373`),
uang (`MoneyService.Add` clamp `MaxCashPerTick*10`, `MoneyService:59-63` + `TickIncome` cap `MaxCashPerTick`,
`PlotManager:66-68`), input dinormalisasi (floor/clamp/upper/strip/batas panjang di semua handler Main).
Client hanya: render (UiTheme/UiPanels), invoke dengan ID/nama, tampilkan hasil. Tidak ada client yang menulis cash/slot.
Satu-satunya kepercayaan client yang tersisa dan WAJAR: `StealPrompt` mengirim `victimUserId` — server tetap verifikasi
keberadaan victim + kepemilikan slot + grown + jarak + lock + safezone + cooldown.

## 7. Kontrak integrasi untuk agen lain (WAJIB dibaca sebelum ubah kode)

1. Remote: SEMUA remote diciptakan di `Main.server.luau:22-36,447-454`. Agen DILARANG `Instance.new("RemoteFunction")`
   di modul lain; tambah remote = tambah di Main + daftarkan di `RATE_LIMITS` (`Main:58-73`) + tambah konsumen di §3.
2. Uang: tulis HANYA via `MoneyService.Add/Spend` (bukan `profile.cash =`, bukan `Set` dinamis). Baca via
   `MoneyService.Get`. `profile.cash` hanya cermin load/save.
3. Slot: mutasi HANYA via `PlotManager.Plant/AddStolenSlot` + hapus eksplisit steal (`Main:356`). Slot key = string
   `"1".."8"`; `FindFreeSlot` = slot otoritas kapasitas. Jangan tambah field slot tanpa update `SaveSystem.ValidateProfile`
   (`SaveSystem:64-79` akan membuang entri rusak — migrasi diam-diam).
4. Save: tambah field profil WAJIB lewat `ValidateProfile` + `defaultProfile` + `snapshot` (yang mengecualikan
   `_uid/_baseAt/_baseSession/offlineEarned). Jangan simpan tanpa `VerifyLock` — ikuti pola `SaveSystem:396-458`.
5. Secret: JANGAN require `TreasureAnswers` / kirim `answerIndex` / koordinat ke client. Riddle baru = tambah di
   `TreasureConfig` (publik) + `TreasureAnswers` (server) + pastikan `GetNextUnsolved` berurutan.
6. UI: gaya HANYA via `UiTheme`; visibilitas HANYA via `UiPanels` (nama terdaftar: `shop`, `profile`, `treasure`);
   ikon HANYA via `UiIcons.Attach` (otomatis hilang bila AssetMap kosong). Jangan hardcode Color3 di client baru.
   ID monetisasi DILARANG hardcode di client — baca dari `RequestInventory` (saat ini semua 0 = "segera hadir").
7. Map: JANGAN rename `Plots`, `Plot_*`, `Owner`, `TradePlaza`, `Shop`, `SpawnLocation` tanpa update
   `Config.SafeZoneName` + `StealSystem.inSafeZone` + `Main assignPlot/releasePlot/visual` + `StealPrompt.hookPlot`.
   Jaga `ServerSize(8) == jumlah plot(8) == MaxSlots(8)`.
8. Produk/gamepass: `Config.Gamepasses/Products` masih 0 (nonaktif aman). Aktivasi = isi ID asli + uji
   `ProcessReceipt` idempoten (`Main:707-719`, `GamepassHandler:42-66`) di Studio dengan purchase nyata — BLOCKED sampai owner mengisi.
9. Aset: isi `AssetMap` HANYA dengan ID upload nyata; `Get()` nil-safe membuat UI/visual tetap jalan tanpa aset.
   Jangan klaim PASS visual sebelum upload+moderasi (BLOCKED, sesuai MASTER6 §Risiko).
10. Uji yang masih NOT TESTED (jangan klaim tanpa bukti): playtest 1/2/8 pemain, DataStore produksi, lock 2-server,
    purchase asli, restock 5 mnt live, steal channel di lag nyata.

## 8. Verifikasi audit MASTER5/6 — putusan Agen 1

- PASS (dengan bukti file:line di atas): hitungan 31 modul MASTER6; 0 TODO; AssetMap kosong; semua 16 remote dipakai;
  jawaban server-only; rate limit penuh; UiPanels eksklusif+Unregister; MapBuilder idempoten per-nama.
- KOREKSI DITERIMA: MASTER5 salah hitung 32 (seharusnya 31) — MASTER6 benar.
- BELUM TERBUKTI (tetap BLOCKED/NOT TESTED, agen QA dilarang klaim PASS): DataStore produksi, 2-server fencing live,
  purchase, upload/moderasi 34 gambar, playtest multi-pemain. Tidak ada bukti baru di `src/` yang mengubah status ini.
- RISIKO BARU dari sesi ini (di atas): R1 (itemLock leak) adalah satu-satunya cacat logika fungsional yang ditemukan;
  sisanya kontrak/robustness. Tidak ada circular require load-time, tidak ada remote yatim, tidak ada otoritas client atas uang/item/jawaban.

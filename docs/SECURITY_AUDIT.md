# SECURITY AUDIT — Steal a Kebun

Tanggal: 2026-11-09. Auditor: AGEN 4 (Security & Exploit Prevention).
Ruang lingkup: `src/Server/Main.server.luau` (satu-satunya file yang boleh diubah)
+ baca-saja service lain & client untuk memetakan payload yang dipercaya.
Kontrak remote milik client TIDAK diubah (nama remote & bentuk return sama;
dicek via `WaitForChild` di `src/Client/*.client.luau`).

## 1. Matriks remote

Arah: C→S = client→server. S→C = server→client (FireClient, tidak bisa di-spoof client).

| Remote | Kelas | Arah | Validasi payload (C→S) | Rate limit | Status |
|---|---|---|---|---|---|
| RequestBuy(itemId) | RemoteFunction | C→S | `string`, ≤64, pola `^[%w_]+$`; `Items.ById` wajib ada; `Secret` ditolak; `EventOnly` wajib event aktif; stok `ShopRotation` dicek + `Take()` dicek; harga & cost dari server (`def.Cost`), tak pernah dari client; `Spend` return dicek, gagal = refund persis via `Set` | 1/dtk | DIPERBAIKI (dulu Spend tak dicek + Take tak dicek) |
| RequestSteal(victimUserId, uid?) | RemoteFunction | C→S | `victimUserId` number finite → floor, 1..9999999999, tolak self; `uid` nil/string ≤64; victim wajib `GetPlayerByUserId` + profil ada; `uid` wajib milik victim + `IsGrown`; slot thief bebas; jarak/kunci/cooldown/zona di `StealSystem.CanSteal`; item diperebutkan via `itemLocks` | 1/dtk | DIPERBAIKI (dulu NaN/fraksi/self lolos ke service) |
| RequestLock() | RemoteEvent | C→S | tanpa argumen (argumen ekstra diabaikan) | 1/dtk | AMAN |
| RequestRebirth() | RemoteFunction | C→S | tanpa argumen; syarat dari `Config.RebirthRequirementFor` (server) | 3/dtk | AMAN |
| RequestDaily() | RemoteFunction | C→S | tanpa argumen; reward dari `DailyReward.Claim` (server), sekali/hari | 5/dtk | AMAN |
| RequestRedeem(code) | RemoteFunction | C→S | `string` ≤32, charset `^[A-Za-z0-9_ ]+$`; reward dari tabel server; sekali pakai/player (`profile.redeemed`) | 3/dtk | DIPERBAIKI (charset guard) |
| RequestRiddle() | RemoteFunction | C→S | tanpa argumen; jawaban TIDAK dikirim (lihat §3) | 1/dtk | AMAN |
| SubmitAnswer(riddleId, choiceIdx) | RemoteFunction | C→S | `riddleId` string ≤16 pola `^[%w_]+$`; `choiceIdx` finite → floor 1..4; urutan riddle ditegakkan service; cooldown + fail-counter + lockout di `TreasureService` | 3/dtk + 5/dtk service | DIPERBAIKI (dulu NaN lolos ke service) |
| RequestHint(riddleId) | RemoteFunction | C→S | `riddleId` string ≤16 pola `^[%w_]+$`; biaya dari `TreasureConfig` (server); `Spend` dicek | 2/dtk | DIPERBAIKI (panjang/pola) |
| CompassPing() | RemoteFunction | C→S | tanpa argumen; wajib `hasCompass`; hanya jarak kasar + arah mata angin, TIDAK pernah koordinat | 2/dtk + 2/dtk service | AMAN |
| RequestDig() | RemoteFunction | C→S | tanpa argumen; wajib `hasShovel`; posisi dari `HumanoidRootPart` server-side; radius 8 stud dari spot server; wajib 1 kunci | 2/dtk + 3/dtk service | AMAN |
| BuyTool(tool) | RemoteFunction | C→S | `string` ≤16, allowlist `"shovel"`/`"compass"`; harga server; `Spend` dicek; `Give*` dicek + refund persis bila balapan | 1/dtk | DIPERBAIKI (dulu tagih ganda saat balapan) |
| RequestStock() | RemoteFunction | C→S | tanpa argumen, read-only | 2/dtk | AMAN |
| RequestInventory() | RemoteFunction | C→S | tanpa argumen, read-only (saldo/rebirth/level/kunci/flag tool) | 2/dtk | AMAN |
| UpdateHud | RemoteEvent | S→C | — (server→client saja: tick/hud/steal_ok/stolen/treasure_found/welcome) | — | AMAN |
| EventState | RemoteEvent | S→C | — (server→client saja, via `EventManager`) | — | AMAN |

Catatan: tidak ada remote yang menerima referensi Instance — seluruh argumen
C→S adalah string/number/none, jadi serangan instance-reference palsu tidak
berlaku di permukaan ini.

## 2. Celah yang ditemukan & diperbaiki (semua di Main.server.luau)

1. **RequestBuy: item gratis via TOCTOU (HIGH).** Urutan lama `Plant → Spend`
   tanpa mengecek return `Spend`, dan return `ShopRotation.Take()` diabaikan.
   Saldo berubah di antara cek dan spend (pembelian konkuren) = item tanpa
   bayar; stok terakhir bisa diklaim dua pembeli. → Sekarang `Spend` dulu
   (dicek), `Plant` gagal = saldo dikembalikan persis, `Take` gagal =
   slot dibatalkan + saldo dikembalikan persis.
2. **Refund via `MoneyService.Add` = over-refund (HIGH, sempat diperkenalkan
   saat perbaikan lalu dibetulkan).** `Add` mengalikan multiplier rebirth
   (s.d. 10x): refund dengan `Add` mencetak uang. → Semua refund memakai
   pola snapshot-`before` + `MoneyService.Set(player, before)`; tidak ada
   yield antara Spend dan Set sehingga atomik lawan income-tick. `Set`
   mentah aman di sini karena nilainya = saldo server sesaat sebelumnya.
3. **BuyTool: tagihan ganda saat balapan (MED).** Dua `BuyTool` konkuren
   sama-sama lolos `hasShovel/hasCompass == false`, dua-duanya `Spend`,
   `Give*` kedua mengembalikan `false` yang diabaikan → bayar 2x, dapat 1x.
   → Return `Give*` dicek; gagal = saldo dikembalikan persis.
4. **RequestSteal: `victimUserId` tak divalidasi bentuk (MED).** Hanya
   `type ~= "number"`: NaN/fraksi/negatif/raksasa lolos; steal diri sendiri
   tidak ditolak dini. → Finite + floor + rentang + tolak self (`"self"`).
   Kepemilikan item & grown tetap diverifikasi ulang di server.
5. **SubmitAnswer: `choiceIdx` NaN lolos (LOW).** `type(NaN)=="number"` dan
   perbandingan `<1`/`>4` salah semua untuk NaN → NaN mencapai service dan
   mengonsumsi cooldown + menambah fail-counter. → Tolak non-finite;
   `riddleId` dibatasi ≤16 + pola.
6. **RequestHint `riddleId` tanpa batas (LOW).** → ≤16 + pola `^[%w_]+$`.
7. **RequestBuy `itemId` tanpa pola (LOW).** → pola `^[%w_]+$` (seluruh ID
   katalog cocok).
8. **RequestRedeem charset (LOW).** → hanya `A-Za-z0-9_ + spasi`, else
   `"kode_salah"`.
9. **Perintah admin `;event`: tanpa cooldown + `menit` tak dibatasi (LOW).**
   `tonumber("999999")` = event ~2 tahun; chat spam = `Start` berulang
   (walau `EventManager` sudah menolak start ganda). → Cooldown 5 dtk/admin
   + clamp 1..120 menit. Otorisasi tak berubah: `Config.AdminUserIds[uid]`
   ATAU `game.CreatorId == uid`; tabel kosong = hanya Creator (nonaktif aman).

## 3. Yang diverifikasi AMAN (tanpa perubahan)

- **Harga/reward/cooldown/purchase otoritas server.** Semua harga dari
  `Items`/`TreasureConfig`, reward dari `DailyReward`/`RedeemCode`/
  `TreasureService`, multiplier dari `MoneyService` + `EventManager`.
  Client tidak pernah mengirim angka yang dipercaya.
- **Jawaban teka-teki tidak bocor.** `TreasureAnswers` hanya di-require
  `TreasureService` (server). `PublicRiddle` mengirim Id/Q/Choices/HintsUsed
  tanpa Zone & tanpa jawaban; `TreasureConfig` replika-client memang memuat
  Q/Choices/Hint/Zone/RewardCash tapi TIDAK memuat answerIndex. Kompas hanya
  mengembalikan `"<riddleId> <jarak> ke <arah>|<beepMs>"`.
- **Ownership plot/item/korban.** Steal memverifikasi slot milik victim +
  grown + jarak + kunci + cooldown + zona; penyelesaian channel memverifikasi
  ulang slot masih ada & grown, lalu memindahkan atomik (gagal = slot asli
  dikembalikan utuh). `itemLocks` mencegah dua pencuri merebut satu item.
- **Proteksi admin.** §2.9; tidak ada perintah admin lain di codebase.
- **Receipt ganda.** `ProcessReceipt` → `GamepassHandler.OnProductBought`
  idempoten via `profile.receipts[PurchaseId]`; grant hanya bila
  `SaveSystem.Save` commit (retry Roblox aman).
- **Session lintas-pemain.** `SaveSystem` fail-closed: claim sesi atomik,
  `VerifyLock` sebelum commit, konflik versi cloud-vs-cloud ditolak.
- **Anti-teleport.** `lastPos` per-tick (150 stud) + jarak channel 25 stud.

## 4. Checklist regresi exploit

| # | Kasus | Hasil audit |
|---|---|---|
| 1 | Spam remote (semua C→S) | Teruji kode: tiap remote ada rate limit (1–5/dtk) + cooldown khusus steal/treasure |
| 2 | Argumen tipe salah / nil / tabel | Teruji kode: `type()` guard di semua handler berargumen |
| 3 | Harga negatif / kuantitas gila dari client | Teruji kode: client tidak mengirim harga/kuantitas; semua dari server |
| 4 | Kuantitas stok negatif / stok habis balapan | DIPERBAIKI + teruji kode: `Take()` dicek, gagal = rollback penuh |
| 5 | Steal tak sah (victim offline, slot tak grown, slot orang lain) | Teruji kode: victim harus online + profil ada + slot milik victim + grown |
| 6 | Akses plot pemain lain | Teruji kode: visual `Owner` hanya untuk HUD; keputusan gameplay tak memakai klaim client |
| 7 | Panen ganda / reward ganda (klik ganda) | Teruji kode: tidak ada tombol panen client; income server-tick; reward riddle/hint/dig dikunci service-side |
| 8 | Notifikasi purchase palsu dari client | Teruji kode: tidak ada remote purchase; satu-satunya jalur = `ProcessReceipt` server |
| 9 | Receipt ganda / retry Roblox | Teruji kode: idempoten `receipts[PurchaseId]` + commit-gated grant |
| 10 | Perintah admin oleh non-admin | Teruji kode: `AdminUserIds` + `CreatorId`, abaikan diam-diam; kosong = aman |
| 11 | Manipulasi data lintas pemain (paksa save pemain lain) | Teruji kode: semua mutasi memakai profil pemilik `player`; tak ada remote berparameter target-profil selain `victimUserId` yang di-resolve server-side |
| 12 | Transaksi konkuren (buy ganda, tool ganda, steal ganda) | DIPERBAIKI + teruji kode (§2.1–2.3) + `itemLocks` steal |
| 13 | Jawaban bocor ke client | Teruji kode: `PublicRiddle`/kompas tak memuat jawaban/koordinat |
| 14 | Event `menit` raksasa / spam `;event` | DIPERBAIKI + teruji kode: clamp + cooldown |

**Catatan jujur:** semua status di atas adalah "teruji kode" (baca statis +
penalaran konkurensi), BUKAN "teruji Studio". Uji runtime berikut WAJIB
dilakukan di Studio sebelum rilis dan berstatus NOT TESTED di sini:
(1) tembak tiap remote dengan Executor-style fuzz (nil/tabel/NaN/Inf/string
raksasa); (2) klik-beli ganda dalam 1 frame untuk stok terakhir & tool;
(3) dua akun rebut satu item steal + satu korban dua pencuri; (4) `;event`
dari akun non-admin & `;event meteor 99999`; (5) replay `ProcessReceipt`
ganda; (6) cek client `TreasureUI` tak pernah menerima jawaban/koordinat
(via Developer Console network/log).

## 5. Gate

- Selene `src`: BERSIH (0 errors, 0 warnings).
- StyLua `--check src/Server/Main.server.luau`: BERSIH.
- StyLua `--check src` (repo-wide): menandai `src/Server/SaveSystem.luau`
  (milik agen lain, sedang diedit konkuren — di luar kepemilikan, tidak disentuh).

## 6. Perintah verifikasi (PowerShell, tanpa `&&`)

```
tools/selene/selene.exe src
tools/stylua/stylua.exe --check src
```

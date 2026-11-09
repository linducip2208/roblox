# Monetisasi — Checklist Konfigurasi Owner (Steal a Kebun)

> Status kode: pembelian **NOT TESTED** di Studio. Wajib uji sandbox sebelum rilis.
> Jangan mengarang ID: semua harga R$ di bawah adalah **target**, ID asli hanya dari dashboard.

## 1. Buat 2 GamePass (dashboard game > Create > Gamepasses)

| Slot Config | Nama saran | Harga target |
|---|---|---|
| `Gamepasses.DoubleMoney` | 2x Uang Permanen | 299 R$ |
| `Gamepasses.VIP` | VIP (lock +10 dtk) | 375 R$ |

1. Buat GamePass satu per satu, catat **Game Pass ID** numerik dari URL/konfigurasi.
2. Aktifkan untuk dijual (for sale).
3. Efek berlaku otomatis: DoubleMoney diverifikasi server (`UserOwnsGamePassAsync`)
   lalu multiplier di-refresh; VIP dibaca live tiap `LockBase` via `isVip()`.

## 2. Buat 2 Developer Product (dashboard game > Create > Developer Products)

| Slot Config | Nama saran | Harga target |
|---|---|---|
| `Products.LuckBoost15m` | Luck Boost 15 menit | 99 R$ |
| `Products.UnlockInstant` | Unlock Instan | 49 R$ |

1. Buat Developer Product satu per satu, catat **Product ID** numerik.
2. DevProduct bersifat habis-pakai (tiap beli = 1 receipt baru) — cocok untuk keduanya.

## 3. Isi 4 ID + AdminUserIds ke `src/Shared/Config.luau`

```luau
Gamepasses = {
	DoubleMoney = 123456789, -- ganti dengan ID asli
	VIP = 987654321,         -- ganti dengan ID asli
},
Products = {
	LuckBoost15m = 111222333, -- ganti dengan ID asli
	UnlockInstant = 444555666, -- ganti dengan ID asli
},
AdminUserIds = {
	[123456] = true, -- ganti dengan UserId kamu
},
```

Aturan:

- `0` = **NONAKTIF aman**: tombol client tampil "(segera hadir)", server menolak
  grant untuk slot itu. Biarkan `0` selama ID belum ada.
- Jangan pernah commit ID orang lain / ID tebakan.
- `AdminUserIds` hanya untuk perintah `;event` — bukan untuk grant item.

## 4. Uji sandbox purchase (wajib, di Studio + akun uji)

1. Buka game di Studio > Play dengan **akun uji** (bukan akun owner).
2. Buka Inventory > tombol monetisasi, pastikan ID sudah tampil (bukan "segera hadir").
3. Beli tiap produk satu per satu:
   - DoubleMoney/VIP: efek multiplier/lock aktif setelah relog juga.
   - LuckBoost15m: status Luck AKTIF, beli 2x = durasi **bertambah** (extend).
   - UnlockInstant: base langsung terbuka.
4. Cek Output server: tidak ada baris `[Shop] produk tak dikenal / nonaktif`.
5. Restart server (Stop > Play): efek persisten (luck dari DataStore, gamepass
   dari API Roblox).

## 5. Ekspektasi retry & idempotensi (jangan "diperbaiki" jadi ack-buta)

- `ProcessReceipt` (di `Main.server.luau:707`) hanya ack `PurchaseGranted`
  jika `OnProductBought` return `true` = **reward + receipt sudah commit ke DataStore**.
- `Save` gagal / pemain belum load / produk tak dikenal → `NotProcessedYet`:
  Roblox akan **retry otomatis**. Ini disengaja agar pembelian tidak hangus.
- Retry dengan `PurchaseId` yang sama = **tidak dobel grant** (cek
  `profile.receipts`; save gagal = tanda dicabut agar retry grant ulang).
- Jangan grant reward dari Remote client manapun. Alur sah satu-satunya:
  client prompt ID server → Roblox memproses pembayaran → server grant via
  receipt/ownership-check.
- Efek `PromptGamePassPurchaseFinished` selalu diverifikasi ulang via
  `UserOwnsGamePassAsync` — notifikasi beli saja tidak cukup.

## 6. Go-live

1. Pastikan keempat ID terisi dan `AdminUserIds` benar.
2. Jalankan `tools/selene/selene.exe src` dan
   `tools/stylua/stylua.exe --check src` hingga bersih.
3. Uji satu pembelian R$ sungguhan nominal kecil, lalu refund bila perlu.
4. Pantau Output server baris `[Shop]` / `[Save]` di 24 jam pertama.

# ROLLBACK PROCEDURE (untuk owner)

Berlaku untuk game yang SUDAH publish. Jika belum publish, rollback = `git revert`
+ `rojo build` ulang saja. Prosedur di bawah jujur terhadap implementasi aktual
(`src/Server/SaveSystem.luau`): tidak ada backup otomatis DataStore di kode.

## 1. Cara kerja penyimpanan (batas yang harus dipahami)

- Kunci: `StealKebun_v1` (`Config.SaveKey`), skema `SCHEMA_VERSION = 2`.
- Format: envelope `{v, session, at, data}`. Migrasi legacy v1 mentah otomatis;
  data korup/validasi gagal = load DITOLAK (tidak ditimpa default) — fail-closed.
- Proteksi timpa: bila cloud lebih baru dari job lain dan bukan basis sesi ini,
  save DIBATALKAN (konflik versi → skip). Artinya data pemain tidak mudah rusak
  oleh server basi, tetapi juga artinya **tidak ada "undo" data per pemain**.
- Session lock: MemoryStore `KebunSessions_v1`, TTL 300 dtk, heartbeat 60 dtk.
  Lock kedaluwarsa sendiri max ~5 menit setelah server mati.
- Receipt DevProduct idempoten via `PurchaseId` (retry aman, tidak dobel grant).
- Validasi clamp: cash 0–1e15, rebirths 0–1000, slot rusak dibuang.

## 2. Backup sebelum publish berisiko (wajib untuk migrasi skema)

Kode tidak membackup otomatis. Lakukan manual:

1. Catat `SaveKey` dan `SCHEMA_VERSION` aktif (saat ini `StealKebun_v1` / 2).
2. Untuk migrasi berisiko: ganti `SaveKey` ke namespace baru
   (mis. `StealKebun_v2`) → publish. Data lama UTUH di bawah kunci lama dan
   bisa dikembalikan hanya dengan mengembalikan `SaveKey` + rebuild + publish.
3. Jangan hapus DataStore dari dashboard. Riwayat versi bawaan DataStore
   (jika tersedia di dashboard) hanya untuk inspeksi manual, bukan restore otomatis.

## 3. Rollback kode (build rusak / bug gameplay)

Tag stabil tersedia: `audit-baseline`. Riwayat: `git log --oneline`.

```powershell
git log --oneline -10
git revert <komit_rusak>
tools/rojo/rojo.exe build default.project.json -o game.rbxlx
```

Lalu buka `game.rbxlx` di Studio → publish ulang ke experience yang sama.
Untuk darurat total: `git checkout audit-baseline` (detached) → build → publish,
lalu kembalikan ke branch kerja setelah insiden selesai. Jangan commit/push
dari kondisi darurat tanpa menandai versinya.

## 4. Nonaktifkan produk bermasalah (tanpa shutdown)

1. Di `src/Shared/Config.luau`: set ID produk bermasalah ke `0`
   (`Gamepasses.*` / `Products.*`). Nilai 0 = nonaktif by design, tidak error.
2. Rebuild + publish ulang.
3. Tambahan di dashboard Roblox: matikan penjualan GamePass/DevProduct tersebut
   (Off Sale) agar tombol beli hilang walau client lama masih memanggilnya
   (server menolak `productId` tak dikenal → tanpa hadiah).

## 5. Darurat steal/dupe exploit (eksploitasi ekonomi aktif)

1. Hentikan pendarahan: Experience dashboard → Servers → **Shutdown All Servers**
   (atau Migrate). Session lock kedaluwarsa sendiri ≤5 menit; jangan langsung
   publish ulang ke server yang masih berisi exploiter.
2. Identifikasi: cek `Analytics` / Leaderboard (cash/rebirth tak wajar — clamp
   kode: cash >1e15 ditolak saat load, tetapi cash hasil exploit di bawah itu
   tetap valid dan TIDAK bisa dibedakan otomatis).
3. Perbaiki kode (validasi server, rate-limit, `MaxCashPerTick`), uji di Studio
   8 klien mengikuti `docs/QA.md` bagian Keamanan.
4. Publish perbaikan ke experience, buka server bertahap (server privat dulu).
5. Pemulihan data korban: tidak ada tool otomatis. Opsi jujur: (a) biarkan
   (data tetap konsisten berkat envelope + clamp), atau (b) untuk kasus berat,
   putar `SaveKey` baru agar SEMUA pemain mulai segar — putuskan dan umumkan
   terbuka ke pemain. Jangan janjikan restore per-pemain yang tidak bisa dilakukan.

## 6. Setelah insiden

- Tulis tanggal, penyebab, komit rollback, dan `SaveKey` aktif ke `docs/UPDATE_NOTES.md`.
- Pastikan `python tools/verify.py` hijau lagi (44 PASS acuan) sebelum klaim pulih.
- Jangan klaim "sudah aman permanen" — catat sisa risiko di `docs/KNOWN_ISSUES.md`.

# DATASTORE ARCHITECTURE — Steal a Kebun

## Key & envelope
- Profil: `GetDataStore("StealKebun_v1")`, key `p_<UserId>`, envelope
  `{ v, session, at, data }`. MemoryStore: SortedMap `KebunSessions_v1`, key `s_<UserId>`.

## Alur join (fail-closed)
1. `ClaimSession` (UpdateAsync atomik: ambil jika kosong/kedaluwarsa/milik sendiri).
   Gagal = kick, TANPA load, TANPA default.
2. `Load`: GetAsync retry 3x + backoff + klasifikasi error
   (throttled/timeout/api_disabled/unavailable) + nama operasi di warn.
3. Bedakan: key kosong = pemain baru (default). Envelope tanpa `.data` tapi ada
   `cash/slots` = migrasi legacy v1. Bentuk lain = KORUP -> tolak, jangan timpa.
4. `ValidateProfile`: angka finite+range, tabel terinisialisasi, slot rusak dibuang,
   receipt >200 entri diprune (>30 hari).
5. Disconnect saat load (`Parent == nil`) = batal, tanpa cache.

## Alur save (commit aman)
1. Syarat: cache ada + loadedOk + token session lokal ada.
2. `VerifyLock`: GetAsync lock, cocokkan token + expiry. Mismatch/tak-terjangkau = SKIP.
3. `MoneyService` sinkron ke profil. Snapshot tanpa field transient.
4. `UpdateAsync`: tolak tulis jika cloud lebih baru dari basis DAN sesi lain.
   Sukses = update `_baseAt/_baseSession`. Konflik = skip (warn), bukan timpa.
5. Autosave 120 dtk + stagger 0.5 dtk. BindToClose paralel (maks ~25 dtk).
   PlayerRemoving: save sekali (guard `savedOnLeave`), release lock milik sendiri.

## Heartbeat & release
- Renew tiap 60 dtk (TTL 300). Mismatch = kick (sesi diambil alih).
- Release via UpdateAsync bersyarat token (tidak hapus milik orang lain).

## Batasan jujur
- Fail-closed berarti: MemoryStore/DataStore down total = pemain tidak bisa main
  (kecuali ephemeral Studio). Ini pilihan desain sesuai prioritas DATA INTEGRITY.
- Receipt: Granted hanya jika `Save()` true. Retry Roblox aman (idempoten PurchaseId).
  Crash di antara grant-vs-save lintas server = kasus langka terdokumentasi, bukan zero-risk.
- Uji live (2 server, shutdown sungguhan, throttle buatan) = NOT TESTED, butuh Studio.

# DATASTORE RACE AUDIT (8 Nov 2026)

## Mekanisme yang dipakai
- **Lock atomik**: `MemoryStore:UpdateAsync` dengan transform murni. Menang hanya jika
  kosong / kedaluwarsa / milik server sendiri. Kalah = kick (fail-closed).
- **Heartbeat 60 dtk** perpanjang TTL 300 dtk. Mismatch = kick (sesi diambil alih).
- **Release aman**: UpdateAsync bersyarat token; tidak pernah hapus lock orang lain.
- **Baca**: `GetAsync` + klasifikasi error (throttled/timeout/api_disabled/unavailable).
- **Tulis**: `UpdateAsync` envelope `{v, session, at, data}` + cek konflik di DALAM
  transform (atomik): tolak jika `old.at > baseAt` DAN `old.session` beda server.
- **VerifyLock pre-commit** (GetAsync): ya, ini jendela TOCTOU baca-lalu-tulis —
  tetapi keputusan akhir SELALU di dalam transform UpdateAsync yang atomik, jadi
  tidak ada lost-update. VerifyLock hanya filter cepat + logging.
- **Backoff+jitter** 3x, autosave stagger 0.5 dtk, BindToClose paralel (maks ~25 dtk),
  guard anti double-save, kick+DropCache saat load gagal.

## Skenario race & hasil analisis (kode, BUKAN live test)
| Skenario | Hasil |
|---|---|
| 2 server klaim bersamaan | Satu menang via UpdateAsync, satu kick. AMAN |
| Server crash, lock kedaluwarsa | Server baru ambil alih setelah exp. AMAN (jeda maks 5 mnt) |
| Tulis bersamaan 2 server | Transform tolak yg basi. AMAN (tidak timpa) |
| Disconnect saat load | Cache dibuang, save dilewati. AMAN |
| Shutdown + PlayerRemoving | Guard savedOnLeave, paralel. AMAN (best-effort) |
| Save gagal 3x | Skip + warn, data memori utuh, coba lagi 120 dtk. AMAN |
|Heartbeat gagal | Kick (fail-closed). AMAN tapi agresif — disengaja |

## Belum terbukti live
Uji 2-server sungguhan, shutdown paksa, throttle buatan: NOT TESTED (butuh Studio).

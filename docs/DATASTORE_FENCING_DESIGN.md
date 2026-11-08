# DATASTORE FENCING DESIGN (protokol versi token+job)

## Identitas sesi
- MemoryStore `KebunSessions_v1` key `s_<uid>` = {job, token=GUID, at, exp}.
  Akuisisi atomik via UpdateAsync: menang hanya jika kosong/kedaluwarsa/milik server
  sendiri. Token GUID per pemain per sesi — BUKAN cuma JobId.
- Envelope profil: {v, session={job, token}, at, data}. Legacy string (hanya JobId)
  dinormalisasi saat load ({job=string, token=nil}) — kompatibel mundur.

## Aturan commit
1. Save wajib: cache ada + loadedOk + token lokal ada.
2. VerifyLock (GetAsync): mismatch/hilang/error = SKIP. Ini filter cepat, BUKAN
   penentu akhir (ada jendela TOCTOU baca-lalu-tulis).
3. Penentu akhir = transform atomik UpdateAsync: tolak (`return old`) jika
   `old.at > base.at` DAN `old.session.job ~= myJob` DAN `old.session.job ~= base.job`.
   Token ikut dibandingkan saat commit sukses (res.token == mine).
4. Backoff+jitter 3x. Konflik = skip + warn (tidak timpa, tidak rusak).
5. Autosave 120 dtk + stagger 0.5 dtk; BindToClose paralel (maks ~25 dtk);
   guard anti double-save; release hanya jika token cocok.

## Skenario simulasi (PENALARAN, BUKAN live test — tidak ada klaim Studio)
| # | Skenario | Hasil analisis |
|---|---|---|
| S1 | 2 server klaim bersamaan | Satu menang atomik; kalah = kick. AMAN |
| S2 | Heartbeat mati, lock kedaluwarsa | Server baru ambil alih; lama di-kick saat heartbeat gagal. AMAN |
| S3 | Save bersamaan 2 server | Transform tolak yg basi. AMAN |
| S4 | Crash di antara grant receipt & save | Retry baca receipt yg sama = Granted tanpa dobel. Tercatat, risiko residual diakui |
| S5 | MemoryStore down total | Fail-closed: tidak bisa main (kecuali ephemeral Studio). AMAN tapi kasar — disengaja |
| S6 | DataStore throttled/timeout | Klasifikasi error + retry 3x; gagal = skip, data memori utuh |
| S7 | Profil korup/unknown | TOLAK load, tidak pernah jadi default. AMAN |
| S8 | Legacy v1 mentah | Migrasi via ValidateProfile. AMAN |
| S9 | Disconnect saat load | Cache dibuang, save dilewati. AMAN |
| S10 | Shutdown + autosave bersamaan | Guard savedOnLeave + paralel. AMAN |

## Batasan jujur
S4 punya jendela kecil: crash tepat setelah commit DataStore tapi sebelum response
dibaca = retry memberi Granted lagi (tetapi receipt sudah tercatat → TIDAK dobel grant).
Uji live 2-server/shutdown paksa: NOT TESTED, butuh Studio.

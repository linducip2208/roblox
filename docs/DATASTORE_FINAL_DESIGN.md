# DATASTORE FINAL DESIGN — Fencing Generation (Steal a Kebun)

Dokumen ini desain final lapisan persistensi: DataStore profil + MemoryStore
lease sesi + fencing generation monotonik. Cakupan file: `src/Server/SaveSystem.luau`.
Harness: `tools/test_fencing.py`. Titik panggil: `src/Server/Main.server.luau`
(`ClaimSession` → `Load` saat `PlayerAdded`; `Save` dari income/steal/treasure/komponen lain).

## 1. Masalah yang diperbaiki (terverifikasi dari sumber)

1. **Takeover tanpa bukti (isu #1).** `ClaimSession` lama mengizinkan ambil alih
   lock bila `old.job == game.JobId`, tanpa membuktikan token sesi lama. Token
   baru tidak membuktikan apa pun tentang sesi lama.
   Perbaikan: syarat SATU-SATUNYA untuk ambil alih = lease kedaluwarsa
   (`SaveSystem.luau:157`, transform `UpdateAsync` MemoryStore). Renew milik
   sendiri tetap via heartbeat dengan perbandingan token persis.
2. **Perbandingan konflik hanya JobId (isu #2).** Aturan save lama membandingkan
   `oldS.job ~= myJob` — token diabaikan, dan `NormalizeSession` untuk sesi lama
   string-only menghasilkan `token = nil` yang lolos perbandingan silang.
   Perbaikan: semua perbandingan identitas memakai pasangan LENGKAP
   `{job, token}` (`SaveSystem.luau:296`, dipakai di `:510`–`:535`).
3. **TOCTOU VerifyLock → UpdateAsync (isu #3).** `VerifyLock` (`:215`) adalah baca
   terpisah; kepemilikan bisa berpindah antara verifikasi dan tulis. Perbaikan:
   `VerifyLock` di `Save` hanya fast-fail diagnostik; OTORISASI FINAL selalu di
   dalam transform `UpdateAsync` terhadap nilai cloud TERKINI (`:510`–`:541`).
   Komentar di `:490`–`:492` menandai ini eksplisit agar tidak regresi.

## 2. Desain fencing generation

Envelope profil (`p_<UserId>`): `{v, gen, session, at, data}`.

- `gen`: bilangan monotonik per profil. Naik +1 atomik di dalam transform
  `UpdateAsync` setiap sesi BARU mengakuisisi, SEBELUM load/mutasi
  (`fenceAndRead`, `SaveSystem.luau:337`). Sesi menyimpan gen miliknya
  (`sessionGen`, ditulis saat `Load` di `:443`).
- Akuisisi + baca = SATU `UpdateAsync` atomik (tidak ada jeda Get lalu tulis):
  pemain baru → envelope `{gen = 1, data = default}`; profil ber-envelope →
  bump gen + set sesi bila sesi BARU, idempoten (gen tidak naik) bila re-fence
  sesi sendiri (retry `Load` di `Main.server.luau` aman); legacy v1 mentah
  (`{cash, slots}` tanpa envelope) → migrasi atomik ke envelope `gen = 1`;
  bentuk lain/korup → ABORT (`return nil`, tanpa tulis) → `Load` fail-closed.
- Transform `Save` (`:510`–`:541`, deterministik, tanpa side-effect eksternal)
  menolak secara atomik bila: (a) `old.gen ~= myGen` — penulis basi, INI yang
  membuat server lama tidak bisa timpa server baru walau `at` sama (resolusi
  `os.time()` 1 detik); (b) identitas sesi cloud bukan milik kita
  (job+token lengkap); (c) `old.at > baseAt` dari sesi asing (sabuk pengaman
  untuk envelope tanpa gen dari versi lama). Tulis sesama sesi sendiri selalu
  diizinkan → autosave + leave-save konkuren aman (last-writer-wins satu sesi).
- Sesudah `Save` sukses, basis (`_baseAt/_baseSession/_baseGen`) dimajukan dari
  hasil komit (`:551`–`:555`) agar save berikutnya konsisten.
- `MemoryStore` (`s_<UserId>`, TTL 300 dtk, heartbeat 60 dtk) HANYA lapis lease
  tambahan: admission cepat + deteksi sesi ganda untuk kick. Otorisasi tulis
  durable TIDAK PERNAH bergantung padanya saja — selalu di-fencing check.
- `ReleaseSession` (`:195`) hanya menghapus lease bila token cocok — tidak
  pernah melepas lock server lain.
- Invarian fail-closed: tidak pernah init default setelah load gagal; tidak
  pernah save profil yang gagal load (`loadedOk`); tidak pernah tulis saat
  `sessionGen` nil; profil lenyap/korup saat save → ABORT.
- Studio: `ClaimSession` SELALU ephemeral bila `RunService:IsStudio()`
  (`:157`–`:165`) — tidak pernah menyentuh DataStore, tidak pernah menulis
  profil palsu ke produksi. Catatan: ini berarti uji save nyata TIDAK BISA
  dilakukan dari Play Solo; lihat §5 NOT TESTED.
- Retry/throttle/timeout/shutdown: `backoff` eksponensial + 3x percobaan di
  fence (`:375`–`:386`) dan save; `PlayerRemoving` (`:580`) + `BindToClose`
  (`:590`, paralel, batas 25 dtk) memakai `savedOnLeave` agar tidak dobel-save;
  autosave melewati pemain yang sudah leave-save (`:567`–`:577`).

## 3. Alur sesi (ringkas)

```
PlayerAdded (Main) -> ClaimSession [lock MemoryStore; Studio=ephemeral]
  -> Load -> fenceAndRead [UpdateAsync: bump gen + baca/migrasi atomik]
  -> gameplay (cache + loadedOk + sessionGen)
  -> Save [VerifyLock fast-fail + UpdateAsync: tolak gen/sesi basi atomik]
  -> PlayerRemoving/BindToClose [Save + ReleaseSession(token-checked)]
```

## 4. Hasil harness (`python tools/test_fencing.py` — 14/14 LULUS)

Harness memodelkan semantik `UpdateAsync` + lease MemoryStore di Python dengan
transform yang MENCERMINKAN callback Luau (diparameterisasi `ProtocolConfig`
agar logika protokol setara). Gagal bila stale writer bisa menang.

| # | Skenario | Hasil | Detail |
|---|----------|-------|--------|
| 1 | pemain_baru | LULUS | gen=1, cash=100 |
| 2 | pemain_lama | LULUS | gen 5→6, cash lama utuh (tak tertimpa default) |
| 3 | migrasi_legacy | LULUS | mentah → envelope gen=1, data terbawa |
| 4 | dua_server_klaim | LULUS | server B ditolak saat lease A hidup |
| 5 | job_sama_token_beda | LULUS | takeover job-sama tanpa bukti token DITOLAK (isu #1) |
| 6 | sesi_kedaluwarsa | LULUS | takeover pasca-expiry diizinkan |
| 7 | stale_save_setelah_claim | LULUS | tulis basi (gen lama) DITOLAK pasca-fence baru (isu #3) |
| 8 | stale_save_setelah_commit | LULUS | **WAJIB**: stale-write DITOLAK dalam detik yg sama, cash baru 5555 UTUH |
| 9 | save_konkuren | LULUS | autosave+leave-save sesama sesi konsisten (last-writer-wins) |
| 10 | datastore_gagal | LULUS | fail-closed: tak ada init default, tak ada save, cloud utuh |
| 11 | shutdown_saat_save | LULUS | retry komit atomik (utuh/gagal total), cash=4242 |
| 12 | rejoin | LULUS | progres terbawa, gen+1 |
| 13 | recovery_gagal_save | LULUS | gagal total lalu pulih (7888 utuh, tanpa mutasi parsial) |
| 14 | release_aman | LULUS | release basi tak melepas lock server baru |

Verifikasi negatif: `python tools/test_fencing.py --demo-legacy` menjalankan
ulang skenario 5/7/8 dengan parameter lama (takeover job-sama + job-only +
tanpa fencing) — ketiganya GAGAL sesuai harapan (bug lama terreproduksi:
cash baru 5555 tertimpa 111 pada skenario 8), membuktikan harness mampu
menangkap regresi. Hasil demo tidak memengaruhi exit code.

## 5. Batas yang masih butuh uji Studio live — NOT TESTED (jujur)

- Perilaku `UpdateAsync` nyata (kontensi, throttle, retry callback) di server
  live — harness memakai model atomik ideal. NOT TESTED.
- Cooldown/kuota DataStore & MemoryStore produksi di beban 8 pemain
  (autosave 120 dtk + heartbeat 60 dtk + steal-save). NOT TESTED.
- `BindToClose` 25 dtk di shutdown game nyata. NOT TESTED.
- Migrasi data produksi legacy v1 bila masih ada (cek isi key `p_*`
  sebelum rilis). NOT TESTED.
- Mode ephemeral Studio hanya diverifikasi via baca kode (cabang
  `IsStudio` di awal `ClaimSession`); save nyata dari Studio TIDAK diuji
  dan TIDAK BOLEH diuji ke produksi. NOT TESTED.
- Kick "akun dipakai di server lain" + rejoin UX (< 5 menit). NOT TESTED.
```


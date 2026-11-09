# RELEASE READINESS (8 Nov 2026)

## Gate teknis (mesin) — LULUS SEMUA
- [x] Rojo build PASS
- [x] Rojo build PASS, Selene 0/0, StyLua PASS, verify 44 PASS / 0 FAIL / 2 BLOCKED (ID+admin owner)
- [x] Tidak ada critical/high bug kode yang diketahui
- [x] Tidak ada data-loss path yang diketahui (fail-closed + envelope + backup validasi)
- [x] Session lock + receipt idempoten terimplementasi (belum uji live)
- [x] Seluruh remote tervalidasi + rate-limited
- [x] 34 aset terverifikasi file-nya (BELUM diupload)

## Gate manusia/owner — TERBUKA (blocker rilis)
- [ ] Studio: Play solo OK (khususnya spawn tidak jatuh, map lengkap, UI rapi)
- [ ] Studio: 8 player (steal, lock, treasure, rebirth, daily, redeem, event)
- [ ] Studio: cek visual HP + tablet + overlap + teks
- [ ] Dashboard: upload 4 (icon+thumb) lalu 22 tanaman lalu 8 ikon; isi AssetMap; rebuild
- [ ] Dashboard: 2 GamePass + 2 DevProduct, isi 4 ID + AdminUserIds ke Config
- [ ] Uji 2-server (session lock), shutdown test, DataStore test di experience terpisah
- [ ] QA.md dicentang + like ratio + sesi bermain dari tester

## Keputusan
**NOT READY — CODE WORK COMPLETE, STUDIO TEST REQUIRED.**
Bukan PUBLICATION READY. Klaim 100/100 hanya setelah semua gate manusia lolos
dengan bukti (screenshot/log/centang QA).

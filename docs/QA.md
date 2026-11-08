# QA CHECKLIST — centang manual di Studio (Test → 8 Clients)

## Fungsional
- [ ] Join: plot ter-assign (Owner = UserId), spawn protection 60 dtk.
- [ ] Beli cabai_noob: cash berkurang, slot terisi, tumbuh 30 dtk.
- [ ] Income tick tiap detik; HUD update; offline earning setelah relog.
- [ ] Lock base 60 dtk; steal saat locked ditolak.
- [ ] Steal tahan 3 dtk dalam 15 stud → item termahal pindah, victim dapat notif.
- [ ] Thief penuh → steal ditolak SEBELUM channel (tidak ada item hilang).
- [ ] Rebirth 1jt → reset + multiplier naik + leaderstats update.
- [ ] Daily claim 1x/hari; redeem RILIS100K 1x saja.
- [ ] Riddle R1 jawab benar → zona + kunci + spot; jawab salah 5x → lockout 60 dtk.
- [ ] Hint: gratis setelah cooldown, bayar 1000 jika buru-buru; max 2/riddle.
- [ ] Kompas: butuh kompas; tampil jarak kasar + arah (TIDAK ada koordinat).
- [ ] Gali: butuh sekop + radius 8 + 1 kunci; reward sekali; relog → spot tetap ada.
- [ ] Selesaikan R1 lalu jawab R2 SEBELUM gali R1 → R1 tetap bisa digali (multi-spot).
- [ ] Event `;event rush 1` (admin): income x2, hint gratis.
- [ ] 2 pemain jawab riddle sama: spot masing-masing terpisah.

## Keamanan (coba bobol)
- [ ] SubmitAnswer dengan choiceIdx 99/-1/string → ditolak, server tidak error.
- [ ] RequestSteal victimUserId string/table → ditolak.
- [ ] Teleport menjauh saat channel → channel batal.
- [ ] Matikan DataStore (coba di Studio dengan API access off) → join ditolak aman, data lama utuh.

## Monetisasi
- [ ] Isi ID GamePass/DevProduct di Config (saat ini 0 = nonaktif, tidak error).
- [ ] Beli Luck → plantedAt maju + luckUntil tersimpan (cek relog masih aktif).

## Aset
- [ ] `python tools/check-assets.py` → isi ID setelah upload, rebuild, Decal muncul di plot.

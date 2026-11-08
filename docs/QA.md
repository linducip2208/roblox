# QA FINAL sebelum publish (wajib centang semua)

## Fungsional (Test 8 player)
- [ ] Beli common sukses, secret ditolak, event-only ditolak saat tidak event
- [ ] Income masuk tiap detik, x2 saat `;event 1`
- [ ] Lock 60s menahan steal, steal luar 15 stud ditolak
- [ ] Steal tahan 3 detik pindah item termahal, victim dapat notif
- [ ] Rebirth 1jt reset + multiplier naik, leaderstats update
- [ ] Relog 1 mnt dapat offline popup
- [ ] Teleport exploit (>150 stud) batalkan channel

## Monetisasi
- [ ] Config.AdminUserIds terisi UserId kamu
- [ ] Gamepass/DevProduct ID terisi (bukan 0)
- [ ] Test beli di sandbox tidak error ProcessReceipt

## Aset
- [ ] `python tools/check-assets.py` = 0 kosong
- [ ] Icon 512 + 3 thumb 1080p terupload + moderasi lolos
- [ ] Like ratio test >85% di 20 tester

## Publish
- [ ] `rojo build -o game.rbxlx` sukses, buka tanpa error
- [ ] Nama BETA, genre Simulation, server 8, PC+Mobile

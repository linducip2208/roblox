# RELEASE CHECKLIST (status aktual 9 Nov 2026 — belum publikasi)

Legenda: [MESIN] = dicek `tools/verify.py` otomatis. [OWNER] = tindakan manual
owner di dashboard/Studio. [MANUSIA] = uji Play di Studio, tidak bisa otomatis.

## Gate MESIN (harus hijau — aktual: hijau kecuali 2 BLOCKED owner)

Hasil aktual `python tools/verify.py` pasca-integrasi: **52 PASS, 0 FAIL,
2 BLOCKED, 6 NOT TESTED.** (Run berikutnya sempat FAIL selene/stylua karena
WIP uncommitted agen paralel di `src/` — bukan kondisi repo yang di-commit.)

- [x] [MESIN] `rojo build` sukses (cek manual terakhir: PASS 8 Nov 2026; verify tidak
  menjalankan build, jalankan sendiri: `tools/rojo/rojo.exe build default.project.json -o game.rbxlx`).
- [x] [MESIN] Selene 0 error 0 warning, StyLua bersih, 0 TODO.
- [x] [MESIN] Skema item (22/22), riddle 10 + Choices, spawn 8 titik, remote parity
  16 OK, rate-limit 14 remote, fencing atomik, no jawaban di client.
- [x] [MESIN] Manifest cocok disk (34 vs 34), 34 file gambar bisa dibuka,
  AssetMap menutup 92 key `assets/out/`.
- [ ] [MESIN→OWNER] BLOCKED `product-ids`: 4 ID masih 0 — isi di dashboard Roblox
  lalu ke `src/Shared/Config.luau` (jangan karang ID).
- [ ] [MESIN→OWNER] BLOCKED `admin-configured`: `Config.AdminUserIds` kosong —
  isi UserId owner untuk perintah `;event`.

## Gate OWNER (dashboard — wajib sebelum beta publik)

- [ ] [OWNER] DataStore API aktif: Game Settings → Security → Studio Access to
  API Services (tanpa ini join ditolak aman / mode EPHEMERAL memori-saja).
- [ ] [OWNER] Icon 512 + 3 thumbnail terupload via dashboard + lolos moderasi
  (sumber: `assets/generated/game-icon/`, `assets/generated/thumbnails/`;
  saat ini semua UPLOAD_PENDING).
- [ ] [OWNER] Minimal 22 Decal item lolos moderasi, `AssetMap.luau` terisi dari
  dashboard, rebuild (`assets/generated/plants/`, semua UPLOAD_PENDING).
- [ ] [OWNER] 2 GamePass (2x Money 299 R$, VIP 375 R$) + 2 DevProduct (Luck 99 R$,
  Unlock 49 R$) dibuat di dashboard, ID dimasukkan ke `Config.luau`.
- [ ] [OWNER] Tidak ada janji publik: dilarang klaim "rilis resmi" atau
  janji penghasilan Robux sebelum semua gate beta lolos.

## Gate MANUSIA (uji Studio — 6 NOT TESTED, semua terbuka)

- [ ] [MANUSIA] `docs/QA.md` fungsional lolos di Studio 8 pemain
  (saat ini NOT TESTED — semua klaim fungsional = PARTIAL, bukan PASS).
- [ ] [MANUSIA] Save/load DataStore sungguhan (experience terpisah + API access).
- [ ] [MANUSIA] Pembelian produk asli (sandbox purchase) + persistensi Luck.
- [ ] [MANUSIA] Visual HP/tablet fisik + screenshot (overlap, keterbacaan).
- [ ] [MANUSIA] Uji 2-server session lock + shutdown sungguhan.
- [ ] [MANUSIA] Like ratio >85% dari 20 tester, sesi rata-rata >10 mnt;
  pengumuman update #1 + kode redeem baru.

## DILARANG sebelum semua gate beta lolos

- Iklan berbayar, klaim "rilis resmi", janji penghasilan Robux.
- Upload `assets/out/*.png` (placeholder PIL) untuk publikasi.
- Mengarang Asset ID / Product ID / UserId.

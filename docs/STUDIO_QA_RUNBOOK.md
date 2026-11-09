# STUDIO QA RUNBOOK — jalan menuju 100/100 (9 Nov 2026)

Skor kini **76/100**; ~24 poin tersisa HANYA terbuka lewat eksekusi manual di
bawah. Setiap kotak yang dicentang + bukti = poin dikonversi. Estimasi:
±2–3 jam kerja aktif + tunggu moderasi (berhari-hari) + metrik beta (berhari-hari).

## SESI 1 — Solo Studio (±30 mnt) → membuka ±6 poin
Play solo (Test → Play). Buka View → Output + Server + Client log.
- [ ] Spawn di TradePlaza (tidak jatuh), 8 plot + Shop terlihat, tanah utuh.
- [ ] Plot ter-assign (Owner = UserId), spawn protection 60 dtk.
- [ ] Beli `cabai_noob`: cash berkurang, slot terisi, tumbuh ±30 dtk.
- [ ] Income tick 1 dtk, HUD update tepat waktu, delta-push tidak bikin label basi.
- [ ] Daily claim 1×; redeem `RILIS100K` 1× saja (kedua kali ditolak).
- [ ] Riddle R1 benar → zona + kunci + spot; salah 5× → lockout 60 dtk.
- [ ] Hint ≤2/riddle; kompas tampil jarak kasar + arah (TANPA koordinat).
- [ ] Gali: butuh sekop + radius 8 + 1 kunci; reward sekali; **relog → spot tetap**.
- [ ] Jawab R1, jawab R2 SEBELUM gali R1 → R1 tetap bisa digali (multi-spot).
- [ ] Tutorial 3 langkah terbaca di viewport 320px (emulasi: device toolbar).
- Bukti: screenshot spawn+HUD+treasure + centang `docs/QA.md`.
- Membuka: Gameplay, UI/UX, World, Mobile (parsial).

## SESI 2 — 2 pemain (±30 mnt) → membuka ±5 poin
Test → 2 Clients (atau 2 Studio). Satu jadi admin (lihat SESI 4 untuk UserId).
- [ ] Steal: tahan 3 dtk dalam 15 stud → item termahal pindah, victim dapat notif.
- [ ] Steal saat locked (60 dtk) ditolak; thief penuh ditolak SEBELUM channel.
- [ ] Teleport menjauh saat channel → channel batal (anti-teleport 150 stud/dtk).
- [ ] 2 pemain jawab riddle sama → spot masing-masing terpisah.
- [ ] Coba bobol: choiceIdx 99/-1/string, victimUserId string/table → ditolak, server tidak error.
- [ ] Rebirth 1jt → reset + multiplier naik + leaderstats update (kedua klien).
- Bukti: log server tanpa error + screenshot notif steal di kedua klien.
- Membuka: Multiplayer (parsial), Security, Ekonomi.

## SESI 3 — 8 pemain (±45 mnt) → membuka ±6 poin
Test → 8 Clients. Ulangi skenario Sesi 2 secara simultan.
- [ ] 8 pemain tanam/panen/steal/treasure bersamaan: tanpa duplikat reward, tanpa saldo negatif, tanpa item hilang.
- [ ] `;event rush 1` (admin): income x2 + hint gratis untuk semua.
- [ ] Polling Shop (10 dtk) + Inventory (15 dtk) tidak bikin lag; HUD 1 Hz stabil.
- [ ] Matikan 1 klien paksa (Stop) → profilnya tersimpan (leave-save), rejoin pulih.
- Bukti: log 8 klien + centang penuh `docs/QA.md` fungsional.
- Membuka: Multiplayer penuh, Performance (profiling nyata), Gameplay penuh.

## SESI 4 — 2 server + shutdown (±30 mnt) → membuka ±4 poin
Butuh: experience PRIVATE terpisah + Game Settings → Security → **Enable Studio
Access to APIs** + DataStore aktif.
- [ ] Isi `Config.AdminUserIds` dengan UserId owner (sementara, revert setelah uji).
- [ ] Server A: pemain join + main. Server B: pemain SAMA join → server A menendang
  (takeover sah), data B = progres terbaru, save basi A DITOLAK (cek log `stale`).
- [ ] Shutdown All Servers (dashboard private exp) → tidak ada data hilang/rollback.
- [ ] API access OFF → join ditolak aman (fail-closed), data lama utuh.
- Bukti: log kedua server + isi DataStore via Studio (DataStore Editor plugin).
- Membuka: DataStore integrity penuh, Session safety.

## SESI 5 — Monetisasi sandbox (±30 mnt) → membuka ±4 poin
Butuh: 2 GamePass (2x Money 299 R$, VIP 375 R$) + 2 DevProduct (Luck 15 mnt 99 R$,
Unlock Instan 49 R$) di dashboard → isi 4 ID + AdminUserIds ke `Config.luau`.
- [ ] Beli Luck → durasi extend + `luckUntil` bertahan setelah relog.
- [ ] Beli Unlock → lock terbuka seketika; beli ganda tidak dobel-tagih.
- [ ] Matikan server di tengah purchase → retry tidak dobel-grant (cek receipts).
- [ ] ID dikosongkan lagi → tombol "segera hadir", tidak error.
- Bukti: struk sandbox + log `PurchaseGranted`/`NotProcessedYet`.
- Membuka: Monetisasi penuh. Detail ID di `docs/MONETIZATION_SETUP.md` §4.

## SESI 6 — Aset + device (±1 jam + tunggu moderasi) → membuka ±5 poin
- [ ] Upload: 1 icon + 22 tanaman + 3 thumb + 8 ikon UI (lihat `assets/ASSET-LIST.md`
  + `docs/ROBLOX_ASSET_UPLOAD.md`); tunggu moderasi lolos semua.
- [ ] Isi 104 kunci `AssetMap`, rebuild (`rojo build`), Decal muncul di plot.
- [ ] Cek visual HP fisik + tablet: 320×568 s/d desktop, portrait/landscape,
  notch, tanpa overlap/clipping (lihat `docs/MOBILE_UI_AUDIT.md`).
- [ ] Icon 512 + 3 thumbnail game di dashboard; like ratio + sesi dari ±20 tester.
- Bukti: screenshot tiap device + moderasi lolos + metrik (like >85%, sesi >10 mnt).
- Membuka: Aset, Mobile penuh, UI penuh, Release (beta).

## Konversi skor (dihitung ulang dari bukti, bukan janji)
| Selesai | Kategori terdongkrak | Estimasi total |
|---|---|---|
| Sesi 1 | Gameplay/UI/World/Mobile parsial | ~79 |
| + Sesi 2 | Security/Ekonomi/Multiplayer parsial | ~83 |
| + Sesi 3 | Multiplayer/Gameplay/Performance penuh | ~88 |
| + Sesi 4 | DataStore penuh | ~92 |
| + Sesi 5 | Monetisasi penuh | ~95 |
| + Sesi 6 | Aset/Mobile/UI/Release penuh + metrik beta | **~100** |

Keputusan naik tingkat: Sesi 1–3 + bukti = **READY FOR PRIVATE BETA**;
semua sesi + metrik = **READY FOR PUBLICATION**. Tanpa bukti = tetap 76.

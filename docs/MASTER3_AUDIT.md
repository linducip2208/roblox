# MASTER3 AUDIT — Steal a Kebun (8 Nov 2026)

## Cakupan
- `src/`: Server 15 modul, Client 8, Shared 8 (termasuk baru: UiPanels, UiTheme).
  `src/World/` TIDAK ADA (disengaja: dunia dibangun runtime oleh MapBuilder;
  terverifikasi idempoten + validasi per nama).
- `game.rbxlx` 115KB hasil `rojo build` PASS. CI workflows: tidak ada (cek manual).
- 0 TODO/FIXME. Selene 0/0. StyLua check PASS. verify.py 17/18.

## Temuan & status
1. **UI abu-abu + spam panel** (laporan pengguna + screenshot): panel default abu-abu,
   teks kepotong, panel numpuk. → FIXED: UiTheme palet resmi, font TextSize,
   tombol lipat + UiPanels eksklusif, HUD navigasi, teks dipadatkan.
2. **Nil ambigu RequestRiddle** ("selesai" palsu saat noload): → FIXED (false+"noload",
   retry otomatis).
3. **Spawn di luar plaza** → pemain baru jatuh ke void (bug kritis gameplay):
   → FIXED (tanah Glass 400 + spawn di atas plaza + validasi).
4. **LockPole CanCollide** menghalangi jalan + tiang rambu sama: → FIXED (false).
5. **MapBuilder duplikat** bila folder Plots parsial: → FIXED (validasi per nama).
6. **DataStore race**: dianalisis di DATASTORE_RACE_AUDIT.md; envelope+token versi
   konsisten; TIDAK ADA SetAsync profil (semua UpdateAsync).
7. Verifikasi UiPanels/UiTheme baru: Selene+StyLua PASS, remote-parity PASS.

## Sisa (butuh Studio/owner — BUKAN kode)
Play 8 player, cek visual HP/tablet, upload 34 gambar, 4 ID + AdminUserIds,
uji 2-server, data produksi. Lihat RELEASE_READINESS.md.

# MASTER4 AUDIT — Steal a Kebun (8 Nov 2026, tanpa commit sesuai perintah)

## Cakupan
- `src/`: Server 15 modul, Client 7 (+StealPrompt/Tutorial/Sound/Hud), Shared 9
  (+UiPanels). `src/World` tidak ada — map dibangun runtime (disengaja).
- CI workflows: tidak ada (cek manual via tools/).
- 0 TODO. Selene 0/0, StyLua PASS, build PASS, verify 20/18.

## Temuan & perbaikan sesi ini
1. UiPanels: registrasi ganda tidak dicek; toggle panel tak terdaftar silent-fail;
   tidak ada Unregister; eksklusivitas hanya saat Toggle. → FIXED: guard duplikat,
   warn jelas, Unregister + hook Destroying, eksklusif sejak Register.
2. HUD tanpa navigasi + tanpa income/level. → FIXED: nav Toko/Harta/Profil via
   UiPanels, tick kirim income+level, animasi pulse saat cash naik.
3. Pohon MapBuilder: silinder salah sumbu (cakram pipih). → FIXED dimensi+posisi.
4. Plot bisa duplikat bila folder parsial. → FIXED: validasi per nama Plot_1..8.
5. `frame.Visible=false` awal di luar registry (TreasureUI). → FIXED: hapus, via Register.
6. Panel tanpa batas ukuran. → FIXED: UISizeConstraint min/max di 3 panel.
7. verify.py: tambah ui-registry-once/toggles/no-rogue-visible + StyLua gate
   (sebelumnya hanya Selene). Total cek: 20 PASS / 1 FAIL (product-ids).

## Tidak diubah (sesuai prioritas & larangan)
- Balancing ekonomi: tanpa perubahan angka (sim tetap valid).
- Schema data: tanpa migrasi baru.
- Tidak ada commit/push/publish.

## Sisa (butuh Studio/owner)
Play 1/2/8, visual HP/tablet, upload 34 gambar, 4 ID + AdminUserIds, uji 2-server,
data produksi, QA centang.

# KNOWN ISSUES (8 Nov 2026 — hanya sisa yang benar-benar terbuka)

## Terbuka (butuh Studio/owner)
1. Play test 1/2/8 pemain belum jalan: semua klaim fungsional = PARTIAL, bukan PASS.
2. Visual HP/tablet + overlap + keterbacaan: NOT TESTED, butuh screenshot device.
3. Upload 34 gambar + 105 kunci AssetMap masih kosong (UPLOAD_PENDING semua).
4. 4 ID produk + AdminUserIds = 0 (monetisasi nonaktif by design).
5. Uji 2-server session lock + shutdown sungguhan + DataStore produksi: NOT TESTED.
6. SafeZone cek `FindFirstChild(SafeZoneName, true)` — jika nama diganti di MapBuilder,
   steal diizinkan di mana saja. Jaga nama "TradePlaza" konsisten.

## Disengaja (bukan bug)
7. Mode EPHEMERAL Studio (unpublished): profil hanya di memori, tidak tersimpan.
   Untuk uji save/load sungguhan: publish private + aktifkan Studio Access to APIs.
8. `src/World/` tidak ada: map dibangun runtime oleh MapBuilder agar `rojo build`
   tetap satu file. Rambu/zona baca di `docs/GDD.md`.
9. Tutorial statis 3 langkah; treasure dijelaskan di panel Treasure. Cukup untuk BETA.
10. ComfyUI batch: jika VRAM habis di tengah batch, file sudah jadi aman, lanjutkan
    manual dari `manifest.json` (status per file).

## Sudah diperbaiki (arsip)
- Spawn di luar plaza (pemain jatuh ke void) → tanah + spawn di plaza.
- LockPole ber-collision menghalangi jalan → CanCollide=false (+ tiang rambu).
- Duplikat plot bila folder parsial → validasi per nama Plot_1..8.
- Pohon silinder salah sumbu → dimensi + posisi dibetulkan.
- UI abu-abu + teks kepotong + panel numpuk → UiTheme + TextSize + panel lipat + UiPanels eksklusif.
- Pesan "selesai" palsu saat data belum load → bedakan noload vs done + retry.
- Session lock fail-open → fail-closed atomik + heartbeat + release aman.
- Transfer steal tidak atomik → cek slot dulu + kembalikan slot asli + item lock.
- Kunci jawaban di Shared → pindah ke TreasureAnswers (server-only).
- `local until` (keyword) + koma hilang 10 riddle → Selene 0/0.

# MASTER8 STUDIO QA — checklist manual 8-pemain / 2-server / datastore / purchase / mobile / aset / end-to-end (9 Nov 2026)

Rujukan langkah detail: `docs/STUDIO_QA_RUNBOOK.md` (Sesi 1–6) dan `docs/QA.md`
(centang fungsional). Dokumen ini HANYA peta cakupan + kriteria lolos Master 8 —
tidak menduplikasi langkah runbook. Semua kotak di bawah = TERBUKA (0 bukti).

## A. 8-pemain (Sesi 3 + QA fungsional)
- [ ] 8 klien tanam/panen/steal/treasure/rebirth simultan: tanpa duplikat, saldo negatif, item hilang.
- [ ] `;event rush 1` (admin) menyebar ke semua klien; polling Shop 10 dtk / Inventory 15 dtk stabil.
- Bukti: log 8 klien + `docs/QA.md` fungsional penuh dicentang.

## B. 2-server session lock (Sesi 4)
- [ ] Pemain sama join server B saat aktif di A → A kick takeover, data B terbaru, save basi A `stale` ditolak.
- [ ] Shutdown All Servers (private exp) → tanpa hilang/rollback.
- Bukti: log 2 server + isi DataStore via plugin editor.

## C. Datastore live (Sesi 4)
- [ ] API Access ON: save/load sungguhan + relog pulih (offline earning ≤8 jam & ≤50% syarat rebirth).
- [ ] API Access OFF: join ditolak aman, data lama utuh (fail-closed).
- Bukti: screenshot DataStore + log fail-closed.

## D. Purchase sandbox (Sesi 5)
- [ ] Luck 99 R$ extend + `luckUntil` bertahan relog; Unlock 49 R$ buka seketika; retry tidak dobel-grant.
- [ ] ID dikosongkan → tombol "segera hadir", tanpa error.
- Bukti: struk sandbox + log `PurchaseGranted`/`NotProcessedYet`.

## E. Mobile / visual device (Sesi 6)
- [ ] HP fisik + tablet, 320×568 s/d desktop, portrait/landscape + notch: tanpa overlap/clipping, teks terbaca.
- Bukti: screenshot tiap device.

## F. Aset end-to-end (Sesi 6)
- [ ] 1 icon + 22 tanaman + 3 thumb + 8 ikon UI lolos moderasi → 104 kunci `AssetMap` terisi → rebuild → Decal muncul di plot.
- [ ] `assets/out/*.png` TIDAK dipakai publikasi (placeholder PIL saja).
- Bukti: moderasi lolos + screenshot Decal di plot.

## G. End-to-end beta exit
- [ ] `docs/QA.md` + runbook Sesi 1–6 penuh dicentang; like >85%, sesi rata-rata >10 mnt (±20 tester).
- [ ] Tanpa bukti = tetap **NOT READY** (skor Master 8 kategori terkait tetap <95).

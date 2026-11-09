# MASTER8 TEST RESULTS — Agen 9 QA & Regresi (9 Nov 2026)

Cakupan milik Agen 9: `tools/verify.py`, `tools/regression_*.py`, doc ini.
`src/` dan tools lain HANYA dibaca/dijalankan. Tanpa commit/push.
Semua output di bawah = aktual verbatim dari run mesin (PowerShell, repo
`D:\project laravel\roblox`). Pohon kerja BERUBAH saat run (agen paralel
mendaratkan patch di tengah sesi QA — tercatat di tiap bagian).

## 1. Perubahan file oleh Agen 9

- `tools/verify.py` (+89 baris): seksi 14c Master 8 (8 cek perilaku baru) +
  hardening `remote-arg-guards` anti-vacuous (`>=10 handler, >=6 param`).
- `tools/regression_master8.py` (BARU): 7 sim regresi Master 8.
- `docs/MASTER8_TEST_RESULTS.md` (BARU): file ini.

## 2. Cek baru di verify.py (14c) + audit false positive/negative

| Cek | Jenis | Hasil |
|---|---|---|
| `m8-hud-deltapush` (R1: snapshot 5 field + gate + cleanup leave) | perilaku (urutan gate vs FireClient + cleanup) | PASS |
| `m8-analytics-queue` (R2: 1 thread, 1 UpdateAsync kode, add, requeue, kunci harian, API 6 utuh) | perilaku (hitung kemunculan di luar komentar + cakupan API) | PASS |
| `m8-perf-a2-assetmap-cache` (tanpa WaitForChild di Refresh + cache modul) | perilaku | PASS |
| `m8-perf-a3-safezone-cache` (tanpa scan rekursif + cache + DescendantAdded) | perilaku | PASS (FAIL di run pertama 44+8 — pola lama `FindFirstChild(Config.SafeZoneName, true)`; agen paralel mendaratkan `safeZonePart` + rebind di tengah sesi QA, kini hijau) |
| `m8-perf-a4-mult-hoist` (Multiplier 1x per tick, sebelum loop pemain) | perilaku (posisi + hitungan) | PASS |
| `m8-perf-a1-visual-scan` (1 scan + peta byOwner per tick visual) | perilaku (scope blok visual saja) | PASS |
| `m8-save-snapshot-hygiene` (semua kunci runtime tertulis ⊆ stripRuntime; `old.data = snap` dari `snapshot(ValidateProfile)`) | perilaku (konsistensi tulis vs kecualikan) | PASS |
| `m8-analytics-flush-exit` (Analytics.Flush + dipanggil saat leave/shutdown) | perilaku | FAIL terbuka (gap Master 8 asli — lihat §4) |

Audit FP/FN existing: `remote-arg-guards` bisa lolos vakum bila handler=0
(di-hardening, kini 13 handler/8 param); `steal-commit-atomic`,
`receipt-idempotent`, `remote-parity`, `rate-limit-coverage` diverifikasi
non-vakum terhadap kode aktual. `ui-fonts.py` SKIP-lines = no-op fixer
(grep: 0 `TextScaled` di `src/Client`); `check-assets.py` = 0 terisi /
104 kosong = placeholder menunggu upload owner (BLOCKED, bukan bug).

## 3. Hasil aktual verbatim

### 3.1 `python tools/verify.py` → FINAL: 52 PASS, 0 FAIL, 2 BLOCKED, 6 NOT TESTED

```text
[PASS] no-answer-leak - ditemukan 0
[PASS] remote-parity - 16 remote OK
[PASS] rate-limit-coverage - 14 remote dilindungi
[PASS] ds-updateasync - fencing atomik ada
[PASS] ds-no-set-profile - tidak ada SetAsync profil
[PASS] ds-normalize-session - identitas sesi job+token
[PASS] ds-verify-before-commit - verify sebelum commit
[PASS] ds-bindtoclose-parallel - shutdown paralel
[PASS] items-unique - 22 item
[PASS] items-schema - 22/22 lengkap
[PASS] riddles-10-unique - 10 riddle
[PASS] riddles-choices - 10/10 punya Choices
[PASS] spawn-points - 8 titik
[PASS] answers-complete
[BLOCKED] product-ids - 4 ID masih 0 -> isi di dashboard Roblox
[PASS] no-todo - 0 sisa
[BLOCKED] admin-configured - kosong - isi UserId owner di Config (untuk ;event)
[PASS] assetmap-covers-out - 92 key OK
[PASS] assets-openable - 34 file, rusak: []
[PASS] assets-resolutions - {(1024, 1024): 23, (1344, 768): 3, (512, 512): 8}
[PASS] manifest-matches-disk - manifest 34 vs disk 34
[PASS] ui-registry-once - terdaftar: ['profile', 'shop', 'treasure']
[PASS] ui-registry-toggles - 4 Toggle via registry
[PASS] ui-no-rogue-visible - 0 assignment langsung di luar registry
[PASS] ui-no-hardcoded-colors - semua via UiTheme
[PASS] ui-no-textscaled - font eksplisit semua
[PASS] ui-responsive-constraints - 3 panel punya batas ukuran
[PASS] remote-arg-guards - 13 handler, 8 param terjaga
[PASS] remote-choice-range - floor + 1..4
[PASS] steal-no-self - CanSteal tolak self
[PASS] steal-uid-ownership - ownership + grown dicek
[PASS] steal-commit-atomic - recheck saat commit + restore
[PASS] money-antineg - tolak negatif/NaN + clamp
[PASS] fencing-token-gen - klaim hanya menang bila token cocok
[PASS] fencing-verify-strict - job+token+generasi, bukan JobId saja
[PASS] fencing-release-own - no-op bila milik orang
[PASS] receipt-idempotent - dedupe->grant->save->unmark
[PASS] treasure-order-lockout - sequence + anti-bruteforce
[PASS] treasure-no-leak-public - respons publik steril
[PASS] save-clamp-profile - load tak pernah percaya data cloud
[PASS] offline-cap - dua cap aktif
[PASS] ui-theme-required - semua panel via UiTheme
[PASS] client-no-datastore - ekonomi hanya server
[PASS] income-cap-config - tick cap + add hardcap
[PASS] m8-hud-deltapush - snapshot+gate+cleanup
[PASS] m8-analytics-queue - spawn=1 upd=1 dipakai=5/5
[PASS] m8-perf-a2-assetmap-cache - cache modul, tanpa yield
[PASS] m8-perf-a3-safezone-cache - zona di-cache
[PASS] m8-perf-a4-mult-hoist - 1x per tick, bukan Nx
[PASS] m8-perf-a1-visual-scan - 1 scan + peta Owner per tick visual
[PASS] m8-save-snapshot-hygiene - runtime ['_baseAt', '_baseGen', '_baseSession', 'offlineEarned'] steril
[PASS] m8-analytics-flush-exit - flush+terpanggil saat exit
[PASS] selene-clean - 0 error 0 warning
[PASS] stylua-clean - format rapi
[NOT TESTED] studio-8player - butuh Play test 8 klien di Studio
[NOT TESTED] studio-datastore-live - butuh experience terpisah + API access
[NOT TESTED] studio-monetization - butuh produk asli + sandbox purchase
[NOT TESTED] studio-visual-device - butuh HP/tablet fisik + screenshot
[NOT TESTED] studio-multiserver - butuh 2 server untuk uji session lock
[NOT TESTED] studio-shutdown - butuh uji BindToClose sungguhan

FINAL: 52 PASS, 0 FAIL, 2 BLOCKED, 6 NOT TESTED
BLOCKED (owner action): product-ids, admin-configured
```

Catatan run: di tengah sesi, run verify sempat 45/7 dan 51/1 (FAIL WIP agen
paralel + `m8-analytics-flush-exit` yang memang belum ada `Analytics.Flush`).
Keduanya diselesaikan saat integrasi orkestrator (implementasi `Flush()` +
wiring BindToClose + LockBase spawn VIP/rebirth); run final di atas 52/0.

### 3.2 `python tools/regression_master8.py` → FINAL: 7 PASS, 0 FAIL (pasca-integrasi)

```text
[PASS] m8-hud-delta-sim - idle diam, berubah kirim, leave bersih
[PASS] m8-analytics-queue-sim - 50 event -> 1 write/key; gagal tak hilang
[PASS] m8-analytics-exitdrain - flush+terpanggil
[PASS] m8-safezone-sim - 6 keputusan cache-identik
[PASS] m8-snapshot-sim - runtime ['_baseAt', '_baseGen', '_baseSession', '_uid', 'offlineEarned'] steril
[PASS] m8-buytool-race-sim - ganda ditolak + refund persis
[PASS] m8-receipt-prune-bound - scan berhenti di 201, basi dipotong

FINAL: 7 PASS, 0 FAIL
```

### 3.3 `python tools/regression_gameplay.py` → FINAL: 9 PASS, 0 FAIL

```text
[PASS] tool-ui-audit - HASIL: OK - 0 TextScaled, semua teks UI berukuran eksplisit
[PASS] tool-check-rarity - rarity item: ['Common', 'Epic', 'Event', 'Legendary', 'Mythic', 'Rare', 'Secret', 'Uncommon'] tak tercover: []
[PASS] tool-sim-economy - 50/50 lolos
[PASS] sim-pacing-rebirth - 5 profil capai r3
[PASS] mutation-ev-match - config 2.25 vs sim 2.25
[PASS] treasure-pacing - riddle total 315000 vs rebirth 1000000
[PASS] offline-cap-binds - uncapped 9216000000000 vs cap 500000
[PASS] rebirth-scale-linear - r0=1000000 r1=2000000 r2=3000000
[PASS] secret-not-sellable - 2 id Secret via steal

FINAL: 9 PASS, 0 FAIL
```

### 3.4 `python tools/regression_security.py` → FINAL: 7 PASS, 0 FAIL

```text
[PASS] redeem-payloads - 8 payload
[PASS] buy-payloads - 6 payload, contoh anggur_roblox/kopi_gacor
[PASS] steal-payloads - 8 payload ownership
[PASS] answer-payloads - 9 payload
[PASS] money-payloads - hardcap 100000000
[PASS] fencing-duel-sim - 7 skenario duel sesi
[PASS] receipt-replay-sim - replay tak dobel grant

FINAL: 7 PASS, 0 FAIL
```

### 3.5 Gate biner: selene 0/0, stylua bersih, rojo build sukses

```text
selene 0.32.0 / Results: 0 errors, 0 warnings, 0 parse errors
stylua 2.6.0 / --check src: RC=0 (tanpa diff)
rojo build default.project.json --output .rojo-test.rbxlx:
  Building project 'StealAKebun' / Built project to .rojo-test.rbxlx / RC=0
```

### 3.6 Tools ekonomi/fencing/audit (dipanggil, bukan diduplikat)

- `tools/sim_economy.py`: 50/50 lolos (agen paralel menambah skenario
  sultan_tick_dicap_10jt, sultan_hardcap_100jt, dsb. — naik dari 25/25).
- `tools/test_fencing.py`: ringkasan 21/21 lulus (naik dari 14/14 —
  skenario payload_raksasa, throttle_beruntun, migrasi_v1_korup,
  autosave_vs_leave_ketat, clock_skew, re_fence_sendiri_berulang,
  release_ganda ditambah agen paralel; semua LULUS).
- `tools/ui-audit.py`: HASIL OK - 0 TextScaled.
- `tools/check-rarity.py`: 8 rarity tercover, tak tercover [].
- `tools/check-assets.py`: Terisi 0 | Kosong 104 (placeholder menunggu upload owner).

## 4. FAIL terbuka (1, bukan milik Agen 9 — butuh agen fitur/src)

- `m8-analytics-flush-exit` (verify) + `m8-analytics-exitdrain`
  (regression_master8): `Server/Analytics.luau` tak expose fungsi flush
  dan tak dipanggil dari `PlayerRemoving`/`BindToClose`. Dampak: jendela
  hilang ≤60 dtk tiap restart/shutdown (disposisi R2: dapat diterima untuk
  analitik, data pemain tetap via SaveSystem). Perbaikan yang ditunggu:
  `Analytics.Flush()` penguras `pending` via `UpdateAsync` + panggil di
  `Main.PlayerRemoving` dan `SaveSystem.BindToClose`. File src read-only
  bagi Agen 9 — sinkron ulang saat integrasi orkestrator.

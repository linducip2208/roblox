# MOBILE LAYOUT AUDIT (8 Nov 2026 — ANALISIS STATIS, BUKAN uji device)

Metode: hitung cakupan piksel panel vs viewport + aturan kode. Tidak ada klaim Play.

## Dimensi panel (kode, sudah termasuk UISizeConstraint max)
| Panel | Ukuran | Posisi | Min | Max |
|---|---|---|---|---|
| Shop | 340x420 | kanan-atas (1,-360,20) | 240x200 | 380x640 |
| Treasure | 340x430 | kiri-tengah | 240x200 | 380x620 |
| Inventory | 300x380 | kanan-tengah | 240x200 | 340x600 |
| HUD cash | 300x44 | kiri-atas (16,16) | - | - |
| HUD nav | 3x94+gap | kanan-bawah | - | - |
| Toggle | 44x44 | sudut panel | - | - |
| Tutorial | 90% lebar | bawah-tengah anchor | - | - |

## Cakupan per viewport (panel penuh terbuka)
| Viewport | Shop (%lebar) | Status | Mitigasi |
|---|---|---|---|
| 320x568 (iPhone SE gen1) | 340 > 320 OVERFLOW | PARTIAL | lipat semua via toggle/HUD; Shop default TERLIPAT jika <700px |
| 360x800 | 94% | PARTIAL | sama di atas |
| 390x844 | 87% | OK dgn lipat | Treasure default terlipat |
| 768x1024 | 44% | OK | - |
| 1366x768 | 25% | OK | - |
| 1920x1080 | 18% | OK | - |

## Checklist persyaratan
- Panel selalu di viewport: YA bila terlipat; PENUH bila terbuka di <=360px (kecuali
  toggle 44px selalu terlihat) → PARTIAL.
- Anchor benar: YA (tepi + tengah-bawah anchor).
- Tidak menutupi karakter berlebihan: YA bila panel dilipat; default Shop terbuka
  di desktop menutupi kanan — gameplay utama di tengah tetap bebas.
- Touch >=44px: YA (toggle 44, tombol 40-48 tinggi; tombol nav 94x44).
- Scroll: YA (ScrollingFrame + auto-canvas di 3 panel).
- Safe area: layout tepi aman; notch tidak diuji → PARTIAL.
- Teks: TextSize eksplisit + Truncate (0 TextScaled) → tidak ada tulisan "bocor",
  tapi BISA terpotong di layar kecil → PARTIAL, perlu cek visual.
- Layout mobile vs desktop: SAMA (belum ada cabang khusus) → PARTIAL.

## Keputusan jujur
Layout KODE-siap responsif parsial; verifikasi visual/device = NOT TESTED.
Butuh: screenshot HP 360px + tablet + desktop dari Play test.

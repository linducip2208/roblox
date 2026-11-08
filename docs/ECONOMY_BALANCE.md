# ECONOMY BALANCE — Steal a Kebun (angka aktual dari Config/Items)

Sumber angka: `src/Shared/Items.luau`, `Config.luau`, `TreasureConfig.luau`,
`DailyReward`, `RedeemCode`. Tidak memakai statistik pasar eksternal.

## 1. Harga & income tanaman (per detik, sebelum multiplier)
| Item | Cost | CPS | BEP (detik) |
|---|---|---|---|
| Cabai Noob | 50 | 1 | 50 |
| Wortel | 150 | 3 | 50 |
| Tomat | 400 | 7 | 57 |
| Jagung | 1.2rb | 18 | 67 |
| Terong | 3rb | 40 | 75 |
| Semangka | 7.5rb | 90 | 83 |
| Pisang | 15rb | 180 | 83 |
| Durian | 35rb | 350 | 100 |
| Anggur | 75rb | 700 | 107 |
| Mangga | 150rb | 1.4rb | 107 |
| Apel | 300rb | 2.8rb | 107 |
| Nanas | 600rb | 5.5rb | 109 |
| Kelapa | 1.2jt | 11rb | 109 |
| Melon | 2.5jt | 22rb | 114 |
| Stroberi | 5jt | 45rb | 111 |
| Leci | 10jt | 90rb | 111 |
| Kiwi | 25jt | 200rb | 125 |
| Sirsak | 50jt | 450rb | 111 |
| Sawit (Secret) | 150jt | 1.2jt | 125 |
| Kopi (Secret) | 500jt | 4jt | 125 |
| Kopi Hujan (Event) | 500rb | 8rb | 63 |
| Payung (Event) | 2jt | 25rb | 80 |

BEP naik perlahan 50→125 dtk: progresi sehat, tier atas butuh komitmen.
Mutasi: Gold x5 (15%), Dark x3 (10%), Rainbow x10 (5%) — jackpot terasa, tidak merusak
karena peluang kecil dan BEP dasar sudah >100 dtk.

## 2. Jalur pemain gratis ke Rebirth pertama (syarat 1jt)
- Riddle R1–R10 reward solve total 315rb + bonus gali 315rb = 630rb.
- Daily minggu-1 total 249.5rb + redeem 400rb = ~650rb.
- Sisa dari income tanaman: 8 slot cabai+tomat ≈ 30/s → 1jt dalam ~9 jam idle.
- Estimasi pemain aktif: 2–4 hari ke rebirth pertama. Sehat untuk simulator.

## 3. Multiplier & cap
- Rebirth +1x tiap level, max x10. DoubleMoney pass x2. Event x2–x4.
- `MaxCashPerTick` 10jt + hard cap 100jt/tick SETELAH multiplier (MoneyService).
- Offline cap 8 jam + max 500rb (50% syarat rebirth) — anti kaya instan.

## 4. Monetisasi (tidak pay-to-win)
- Pass mempercepat (2x, +10 dtk lock, luck 15 mnt), tidak membuka konten eksklusif kuat.
- Secret hanya via steal (tidak bisa dibeli) → free player bisa pamer status.
- Unlock Instant hanya buka kunci sendiri, bukan curi lebih kuat.

## 5. Risiko inflasi
- Income tick tanpa sink (uang tidak pernah keluar kecuali beli/rebirth).
- Penyeimbang: biaya naik eksponensial, rebirth reset cash, shop stok terbatas.
- NEXT: tambah sink (upgrade plot berbayar, skin) jika median cash pemain >50jt di bulan 1.

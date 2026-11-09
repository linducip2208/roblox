# ULTIMATE TEST RESULTS (9 Nov 2026 — hasil aktual mesin, verbatim)

Perintah dijalankan dari repo root `D:\project laravel\roblox`:

| Perintah | Hasil aktual |
|---|---|
| `python tools/verify.py` | `FINAL: 44 PASS, 0 FAIL, 2 BLOCKED, 6 NOT TESTED`, exit 0. BLOCKED = `product-ids`, `admin-configured` (owner). NOT TESTED = 6 skenario Studio-only |
| `tools/selene/selene.exe src` | `0 errors, 0 warnings, 0 parse errors`, exit 0 |
| `tools/stylua/stylua.exe --check src` | kosong (bersih), exit 0 |
| `tools/rojo/rojo.exe build default.project.json -o game.rbxlx` | `Built project to game.rbxlx`, exit 0 |
| `python tools/test_fencing.py` | `ringkasan: 14/14 lulus` (termasuk stale-save-setelah-commit DITOLAK, cash 5555 utuh), exit 0 |
| `python tools/regression_gameplay.py` | `FINAL: 9 PASS, 0 FAIL` (termasuk sim_economy 25/25), exit 0 |
| `python tools/regression_security.py` | `FINAL: 7 PASS, 0 FAIL` (39 payload adversarial + duel fencing 7 skenario + replay receipt), exit 0 |
| `python tools/ui-audit.py` | `HASIL: OK - 0 TextScaled`, exit 0 |
| `python tools/check-rarity.py` | `tak tercover: []` (8/8 rarity), exit 0 |
| `python tools/sim_economy.py` | `25/25 lolos` + rebirth-3 profil (hari-6), exit 0 |

## NOT RUN / NOT TESTED (butuh Roblox Studio / perangkat / owner — bukan PASS)
Play 1/2/8 pemain, join/leave, steal simultan, treasure end-to-end + relog,
save/load/shutdown/DataStore produksi, GamePass/DevProduct asli + sandbox purchase,
visual HP/tablet + overlap + keterbacaan, server/device/network simulation,
uji 2-server, receipt retry live, upload 34 gambar + moderasi, isi 104 kunci AssetMap,
isi 4 ID produk + AdminUserIds, like ratio + sesi tester.

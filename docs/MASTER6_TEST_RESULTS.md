# MASTER6 TEST RESULTS (9 Nov 2026 — hanya yang dijalankan mesin)

| Uji | Hasil | Bukti |
|---|---|---|
| Rojo build | PASS | game.rbxlx terbangun ulang |
| Selene | PASS | 0 error, 0 warning (via verify.py) |
| StyLua | PASS | 0 diff (via verify.py) |
| verify.py | 27 PASS, 0 FAIL, 2 BLOCKED, 6 NOT TESTED, exit 0 | BLOCKED=product-ids, admin-configured (owner); NOT TESTED=Studio-only |
| ui-audit.py | PASS | 0 TextScaled tersisa |
| check-rarity.py | PASS | rarity tercover UiTheme |
| sim_economy.py | INFO | model, bukan janji |
| validate_assets | PASS | 34/34 OK, manifest cocok (via verify.py) |

## NOT RUN (butuh Roblox Studio / owner — tidak diklaim)
Play 1/2/8 pemain, join/leave, steal simultan, treasure end-to-end (termasuk relog),
save/load/shutdown/data produksi, GamePass/DevProduct asli, visual HP/tablet,
server/device/network simulation, uji 2-server, receipt retry live,
upload 34 gambar + isi 104 kunci AssetMap + 4 ID produk + AdminUserIds.

# MASTER5 TEST RESULTS (9 Nov 2026 — hanya yang dijalankan mesin)

| Uji | Hasil | Bukti |
|---|---|---|
| Rojo build | PASS | game.rbxlx 115KB |
| Selene 0.32.0 | PASS | 0 error, 0 warning |
| StyLua | PASS | 0 diff |
| verify.py | 27 PASS, 0 FAIL, 2 BLOCKED, 6 NOT TESTED, exit 0 | BLOCKED=product-ids, admin-configured (owner); NOT TESTED=Studio-only |
| ui-audit.py | PASS | 0 TextScaled tersisa |
| check-rarity.py | PASS | 8/8 rarity tercover |
| sim_economy.py | INFO | r1 H2, r2 H4, r3 H6 (model, bukan janji) |
| validate_assets | PASS | 34/34 OK, manifest cocok |
| check_comfyui | PASS | v0.43.0, RTX 4060, model+node OK |
| Map audit | PASS | idempoten, validasi per nama, spawn di plaza, tanpa duplikat |
| UI registry test | PASS | once/toggles/no-rogue/unregister |
| Rate-limit coverage | PASS | 15/15 RemoteFunction |
| Fencing protocol | PASS | UpdateAsync+token, tanpa SetAsync profil |

## NOT RUN (butuh Roblox Studio — tidak diklaim)
Play 1/2/8 pemain, join/leave, steal simultan, treasure end-to-end (termasuk relog),
save/load/shutdown/data produksi, GamePass/DevProduct asli, visual HP/tablet,
server/device/network simulation, uji 2-server, receipt retry live.

# MASTER3 TEST RESULTS (8 Nov 2026 — hanya yang dijalankan mesin)

| Uji | Hasil | Bukti |
|---|---|---|
| Rojo build | PASS | game.rbxlx 115KB |
| Selene 0.32.0 | PASS | 0 error, 0 warning di src/ |
| StyLua check | PASS | 0 diff |
| verify.py | 17/18 | 1 FAIL = product-ids-set (BLOCKED owner, by design) |
| verify: remote parity | PASS | 15+2 remote cocok |
| verify: rate-limit coverage | PASS | semua RemoteFunction client->server tercover |
| verify: no-answer-leak | PASS | 0 kunci di Shared |
| verify: items schema | PASS | 22/22 lengkap, unik |
| verify: riddles/answers/spawns | PASS | 10/10, jawaban server-only |
| verify: assetmap vs out | PASS | kunci lengkap |
| verify: assets openable | PASS | 34/34 PIL OK |
| verify: manifest==disk | PASS | 34==34 |
| sim_economy | INFO | rebirth-1 H2, r2 H4, r3 H6 (model optimal; bukan janji) |
| ui-audit | PASS | 0 TextScaled tersisa |
| rarity coverage | PASS | 8/8 |
| check CozyUI server | PASS | v0.43.0, RTX 4060 |
| asset validate | PASS | 34/34 OK |

## NOT RUN (butuh Roblox Studio — tidak diklaim)
Play 1/2/8 pemain, join/leave plot, steal simultan, treasure end-to-end,
save/load/shutdown produksi, GamePass/DevProduct asli, mobile UI + device,
network/server shutdown simulation, uji visual HP.

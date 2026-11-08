# FINAL GAMEPLAY AUDIT (8 Nov 2026 — audit kode, tanpa ubah balancing)

| Fitur | Server-validasi | Anti-duplikat | Cooldown/rate | Status tes live |
|---|---|---|---|---|
| Plot assign/release | Owner=UserId permanen | slot per pemain | - | NOT TESTED |
| Plant/beli | harga+stok+slot server | plant atomik | 1 dtk | NOT TESTED |
| Growth/income | TickIncome server, IsGrown | - | 1 dtk tick | NOT TESTED |
| Offline | cap 8 jam + 50% syarat | sekali saat load | - | NOT TESTED |
| Steal | jarak/channel/uid/grown/slot/lock/safezone | item lock + restore slot asli | 5 dtk + 1 dtk | NOT TESTED |
| Lock | server-side, VIP/rebirth | - | tombol 1 dtk | NOT TESTED |
| Rebirth | syarat skala linear server | reset atomik | 3 dtk | NOT TESTED |
| Daily | %Y%j streak | sekali/hari | 5 dtk | NOT TESTED |
| Redeem | map sekali pakai | PurchaseId-like per kode | 3 dtk | NOT TESTED |
| Shop rotation/restock | server-only stock | Take atomik | 10 dtk refresh | NOT TESTED |
| Treasure solve | jawaban server-only, urutan | solved flag | 5 dtk + lockout | NOT TESTED |
| Hint | 2/riddle, koin/cooldown | hintsUsed | 2 dtk | NOT TESTED |
| Compass | jarak kasar, tanpa koordinat | - | 2 dtk | NOT TESTED |
| Dig | radius 8 + sekop + 1 kunci | found flag + hapus spot | 2+3 dtk | NOT TESTED |
| Inventory | server-side grant | SpendKeys tunggal | - | NOT TESTED |
| Events (4) | Multiplier()/HintFree() server | guard tumpang tindih | admin only | NOT TESTED |
| Leaderboard | attach server | - | 2 dtk update | NOT TESTED |
| Monetisasi | ProcessReceipt idempoten | PurchaseId | - | BLOCKED (ID=0) |

Balancing: TIDAK DIUBAH (sim_economy tetap acuan; tuning hanya dari data live).

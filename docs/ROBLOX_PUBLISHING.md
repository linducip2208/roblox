# ROBLOX PUBLISHING (langkah manual, tidak bisa otomatis)

1. Buka `game.rbxlx` di Roblox Studio (hasil `rojo build`).
2. Game Settings → Security → aktifkan Studio Access to API Services (untuk DataStore test).
3. File → Publish to Roblox As → nama `Steal a Kebun [BETA]`.
4. Experience Settings: Genre Simulation, server 8 pemain, perangkat PC + Mobile.
5. Icon + thumbnail: upload via dashboard Create → Thumbnails (bukan via Rojo).
6. Monetization: buat 2 GamePass (2x Money 299, VIP 375) + 2 DevProduct (Luck 99,
   Unlock 49) → salin ID ke `src/Shared/Config.luau` → rebuild + publish ulang.
7. Permissions → privasi server sesuai kebutuhan beta.

Catatan: repo ini TIDAK mempublish otomatis. Jangan beri token Roblox ke siapa pun.

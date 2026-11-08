# Steal a Kebun — Roblox Simulator + Steal PvP [BUILD OK ✅]

Genre: Simulation idle + Steal (ala Grow a Garden x Steal a Brainrot)
Target: monetisasi serius, update mingguan Sabtu
Status: **22 Luau, 0 TODO, `rojo build` sukses (game.rbxlx 53KB)**

## Quick Start (Drive D:)
1. Install Roblox Studio ke D: — `PowerShell -ExecutionPolicy Bypass -File tools/install-studio-D.ps1` (as Admin)
2. Serve: `tools/rojo/rojo.exe serve` dari folder `roblox/` (atau `rojo serve` jika sudah di PATH)
3. Studio → plugin Rojo → Connect localhost:34872 → Play 8 player
4. Atau buka langsung: `game.rbxlx` (hasil build, double-click buka di Studio)

## Struktur
- `src/Shared/Config.luau` — balancing + AdminUserIds + Gamepass ID
- `src/Shared/Items.luau` — 22 item (20 + 2 event Hujan Kopi)
- `src/Shared/ShopRotation.luau` — restock 5 mnt FOMO
- `src/Shared/AssetMap.luau` — isi rbxassetid setelah upload ComfyUI
- `src/Server/` — Main, Save, Plot, Steal, Money, MapBuilder, Leaderboard, Event, Daily, Redeem, Analytics
- `src/Client/` — Shop full, Hud, StealPrompt (auto termahal), Tutorial, Sound (tanpa aset)
- `assets/` — ASSET-LIST (34 file), prompts, workflow json, out/
- `docs/` — GDD, INSTALL-D, LAUNCH, EVENT-SABTU, QA

## Loop Inti
Tanam (30s-75mnt) -> Panen offline max 8 jam -> Jual -> Beli langka -> Steal tahan 3 detik (lock 60s) -> Rebirth 1jt = x2

## Kode Test
- `RILIS100K` 100rb, `HUJANKOPI` 50rb, `GACOR2026` 250rb
- Admin chat: `;event 1` (mulai event 1 mnt, hanya AdminUserIds)
- Daily: 500 → 150rb streak 7 hari

## Monetisasi (isi ID di Config.luau)
- 2x Money 299R$, VIP 375R$, Luck 15mnt 99R$, Unlock 49R$

## Aset ComfyUI
`python tools/check-assets.py` — saat ini 0/26. Lihat `assets/ASSET-LIST.md`.
Game tetap jalan tanpa aset (fallback bola warna + suara bawaan).

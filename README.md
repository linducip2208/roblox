# Steal a Kebun — Roblox Simulator + Steal PvP [BUILD OK ✅]

Genre: Simulation idle + Steal (ala Grow a Garden x Steal a Brainrot)
Target: monetisasi serius, update mingguan Sabtu
Status: **31 modul Luau, 0 TODO, Selene 0/0, StyLua PASS, `rojo build` sukses, `tools/verify.py` 20/21**

## Quick Start (Drive D:)
1. Install Roblox Studio ke D: — `PowerShell -ExecutionPolicy Bypass -File tools/install-studio-D.ps1` (as Admin)
2. Serve: `tools/rojo/rojo.exe serve` dari folder `roblox/` (atau `rojo serve` jika sudah di PATH)
3. Studio → plugin Rojo → Connect localhost:34872 → Play 8 player
4. Atau buka langsung: `game.rbxlx` (hasil build, double-click buka di Studio)

## Cek mutu (dari folder `roblox/`, tanpa Studio)
```powershell
python tools/verify.py        # 15 cek: remote, skema, jawaban, ID, aset
& tools/selene/selene.exe src # harus 0 error 0 warning (selene.toml)
& tools/stylua/stylua.exe --check src  # harus bersih (stylua.toml)
& tools/rojo/rojo.exe build default.project.json -o game.rbxlx
```

## Struktur
- `src/Shared/` - Config, Items (22 item + 2 event), ShopRotation, TreasureConfig (tanpa jawaban),
  AssetMap (105 kunci, 0 terisi = UPLOAD_PENDING), UiTheme (palet+font), UiPanels (registry eksklusif), UiIcons (ikon+fallback)
- `src/Server/` — Main, Save (fail-closed lock+envelope), Plot, Steal (item lock),
  Money, MapBuilder, Leaderboard, Event (katalog 4), Daily, Redeem, Analytics,
  TreasureService (multi-spot), TreasureAnswers (SERVER ONLY), Inventory, Gamepass
- `src/Client/` — Shop (stok real-time), Hud, StealPrompt, Tutorial, Sound (mute),
  TreasureUI, InventoryUI (profil+gamepass+settings)
- `assets/generated/` — 26 render SDXL + 8 ikon UI + manifest.json (butuh upload manual)
- `assets/out/` — 92 placeholder PIL (JANGAN upload untuk publikasi)
- `docs/` — GDD, INSTALL-D, LAUNCH, EVENT-SABTU, QA, audit, ekonomi, skor, rilis
- `tools/` — verify, sim_economy, Selene/StyLua/Rojo biner lokal (abaikan di git kecuali toml)
- `tools/comfyui/` — check, generate_icons, validate_assets + README

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

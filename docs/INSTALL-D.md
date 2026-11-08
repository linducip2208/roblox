# Install Roblox Studio di Drive D:

Studio resmi selalu default ke C:\Users\%USERNAME%\AppData\Local\Roblox.
Trik: install dulu, lalu pindah + symlink ke D:\ agar update tetap jalan.

## Otomatis (Recommended)
Jalankan PowerShell sebagai Administrator:
```powershell
PowerShell -ExecutionPolicy Bypass -File "D:\project laravel\roblox\tools\install-studio-D.ps1"
```

## Manual
1. Download + install dari https://www.roblox.com/create
2. Tutup Studio sepenuhnya
3. Pindah folder:
```
move "%LocalAppData%\Roblox" "D:\Roblox"
mklink /J "%LocalAppData%\Roblox" "D:\Roblox"
```
4. Buka Studio, login, install plugin Rojo (search "Rojo" di Toolbox -> Plugins)
5. Di VS Code / terminal:
```
cd "D:\project laravel\roblox"
rojo serve
```
6. Di Studio: Rojo -> Connect -> localhost:34872 -> Play untuk test 8 player (Test -> Clients and Servers -> 8)

## Cek instalasi
- `D:\Roblox\Versions\RobloxStudioBeta.exe` harus ada
- symlink `C:\Users\...\AppData\Local\Roblox -> D:\Roblox` (cek dengan `dir %LocalAppData%`)

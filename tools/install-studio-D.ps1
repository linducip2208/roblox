#Requires -RunAsAdministrator
# Pindah Roblox Studio ke D:\Roblox via Junction agar update tetap jalan
$src = "$env:LOCALAPPDATA\Roblox"
$dst = "D:\Roblox"

Write-Host "SRC: $src"
Write-Host "DST: $dst"

if (-not (Test-Path $src)) {
  Write-Host "Roblox belum terinstall di $src. Install dulu dari https://www.roblox.com/create lalu jalankan lagi script ini."
  exit 1
}
if (Test-Path $dst) {
  Write-Host "D:\Roblox sudah ada, skip move. Pastikan symlink benar."
} else {
  Write-Host "Memindah $src -> $dst ..."
  Move-Item -Path $src -Destination $dst -Force
}
# buat junction jika belum ada
if (-not (Test-Path $src)) {
  cmd /c mklink /J "$src" "$dst"
  Write-Host "Junction dibuat."
} else {
  Write-Host "SRC masih ada (mungkin sudah junction). Cek: dir $env:LOCALAPPDATA"
}
Write-Host "Selesai. Buka D:\Roblox\Versions\RobloxStudioBeta.exe untuk pastikan jalan."

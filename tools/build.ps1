# Build + Test Roblox di Drive D:

# 1. Jalankan Rojo (di D:\project laravel\roblox)
# rojo serve  -> lalu Connect dari Studio
# rojo build -o game.rbxlx  -> hasil file bisa dibuka langsung tanpa serve

# 2. Test 8 player (wajib sebelum publish)
# Di Studio: Test -> Clients and Servers -> 8 -> Start
# Checklist:
# - beli cabai_noob sukses, cash berkurang
# - tunggu 30 detik, income tick masuk
# - lock base 60s, steal ditolak saat locked
# - steal tahan 3 detik dalam 15 stud sukses
# - rebirth 1jt reset + x2 multiplier
# - relog: offline earning muncul (tutup Play Solo, tunggu 1 mnt, join lagi)
# - exploit: speed hack / teleport >150 stud = channel batal

Write-Host "Jalankan: rojo serve  (lalu Rojo Connect di Studio)"

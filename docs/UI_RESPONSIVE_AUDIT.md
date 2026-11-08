# UI RESPONSIVE AUDIT (8 Nov 2026 — berbasis kode, BUKAN uji device)

## Sistem (src/Shared/UiTheme.luau + UiPanels.luau)
- Palet resmi terkunci di satu modul; tidak ada `Color3.fromRGB` di Client
  (terverifikasi via grep — 0 temuan).
- Font: Gotham/GothamBold + TextSize eksplisit + TextTruncate (0 TextScaled di Client).
- UICorner 8 + UIStroke 1px + UIPadding 6 via helper (konsisten).
- Satu panel utama aktif (UiPanels eksklusif); HUD (DisplayOrder 20) berisi nav
  Toko/Harta/Profil + tombol lipat per panel (44px, >= target sentuh 44px).
- Toggle: buka-tutup via registry yang sama (tidak ada state ganda).

## Responsivitas per ukuran (analisis statis)
- Panel 300-340px + ScrollingFrame + AutomaticCanvasSize: muat layar >=360px lebar.
- Layar <360px (HP kecil landscape): panel menutupi sebagian gameplay — mitigasi =
  lipat semua panel (1 ketuk). Dinyatakan PARTIAL sampai uji device.
- Topbar Roblox: ScreenGui default (IgnoreGuiInset=false) → offset aman.
- Safe area/notch: belum diverifikasi device → PARTIAL.

## Yang belum bisa diklaim
Uji HP/tablet fisik, overlap aktual, keterbacaan teks kecil di layar 5",
animasi hover di sentuh (no-op, aman). Status: PARTIAL, butuh foto Play dari owner.

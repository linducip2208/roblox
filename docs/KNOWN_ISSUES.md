# KNOWN ISSUES

1. ~~Session ownership ganda belum di-lock~~ SELESAI (v0.3.0): MemoryStore fail-closed
   (`ClaimSession` atomik via UpdateAsync + token + heartbeat 60 dtk + release aman).
   Sisa: uji 2 server (NOT TESTED).
2. ~~`Analytics.Buy(0)` untuk progres riddle~~ SELESAI (v0.2.2): counter sendiri
   `Analytics.Riddle()` (`riddle_solved`).
3. ~~Shop client tidak tahu stok real-time~~ SELESAI (v0.2.1): `RequestStock` +
   label stok + countdown restock 10 dtk di ShopUI.
4. SafeZone cek `FindFirstChild(SafeZoneName, true)` — jika nama diganti di MapBuilder,
   steal diizinkan di mana saja. Jaga nama "TradePlaza" konsisten.
5. Mode EPHEMERAL Studio (unpublished): profil hanya di memori, tidak tersimpan.
   Untuk uji save/load sungguhan: publish private + aktifkan Studio Access to APIs.
5. `src/World/` tidak ada (disengaja): map dibangun runtime oleh MapBuilder agar
   `rojo build` tetap satu file. Rambu/zona baca di `docs/GDD.md`.
6. Tutorial statis; treasure dijelaskan di panel Treasure. Cukup untuk BETA.
6. ComfyUI batch: jika VRAM habis di tengah batch, file sudah jadi aman, lanjutkan
   manual dari `manifest.json` (status per file).

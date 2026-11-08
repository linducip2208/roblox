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
5. Tutorial statis 3 langkah; belum cover treasure. Cukup untuk BETA.
6. ComfyUI batch: jika VRAM habis di tengah batch, file sudah jadi aman, lanjutkan
   manual dari `manifest.json` (status per file).

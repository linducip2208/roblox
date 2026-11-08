# KNOWN ISSUES

1. Session ownership ganda (2 server tulis DataStore bersamaan, mis. pindah server cepat)
   belum di-lock (butuh MemoryStore). Mitigasi: retry + loadedOk. Risiko: item duplikat
   lintas server. Prioritas: sebelum public beta.
2. `Analytics.Buy(0)` dipakai untuk progres riddle — counter kasar, perbaiki saat butuh dasbor.
3. Shop client tidak tahu stok real-time (server-only). UX: beli gagal "out_of_stock".
   Perbaikan NEXT: Remote stok snapshot tiap restock.
4. SafeZone cek `FindFirstChild(SafeZoneName, true)` — jika nama diganti di MapBuilder,
   steal diizinkan di mana saja. Jaga nama "TradePlaza" konsisten.
5. Tutorial statis 3 langkah; belum cover treasure. Cukup untuk BETA.
6. ComfyUI batch: jika VRAM habis di tengah batch, file sudah jadi aman, lanjutkan
   manual dari `manifest.json` (status per file).

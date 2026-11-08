# MASTER5 AUDIT — Steal a Kebun (8-9 Nov 2026, tanpa commit sesuai perintah)

## Cakupan
- `src/`: Server 15, Client 7, Shared 10 (baru: UiPanels). TOTAL 32 modul Luau.
- 0 TODO. Selene 0/0, StyLua PASS, build PASS, verify 29/29 PASS + 2 BLOCKED + 6 NOT TESTED.
- ui-audit: 0 TextScaled di Client. check-rarity: 8/8 tercover. validate 34/34 cocok manifest.

## Temuan & perbaikan sesi ini
1. **UiTheme tidak konsisten**: 5 hardcode Color3 di Client + `UiTheme.Accent` usang.
   → FIXED: semua lewat UiTheme (terverifikasi grep = 0 sisa).
2. **Tutorial fixed 400px + teks kepotong**: → FIXED anchor tengah + scale 0.9 + Wrap/Truncate.
3. **MapBuilder tidak idempoten penuh** (duplikat bila folder parsial, LockPole nabrak,
   spawn di luar plaza = jatuh void, silinder pohon salah sumbu).
   → FIXED: validasi per nama Plot_1..8 + repair Owner/LockPole, tanah 400x400,
   spawn di plaza, CanCollide=false non-struktur, pohon betulkan.
4. **Fencing DataStore**: session envelope = JobId saja (tanpa token).
   → FIXED: `NormalizeSession`, conflict rule job+token, verify pre-commit,
   BindToClose paralel, receipts timestamp + prune 30 hari.
5. **Rate limit**: 2 remote lolos (RequestStock read-only, RequestInventory).
   → FIXED: semua 15 RemoteFunction tercover (verify membuktikan).
6. **UiPanels**: tanpa Unregister, toggle tak dikenal silent, eksklusif tidak sejak awal.
   → FIXED + verify ui-registry-once/toggles/no-rogue-visible.
7. **HUD tanpa navigasi/income**: → FIXED nav Toko/Harta/Profil + income/s + level + pulse.
8. **Simulasi 2-server**: dibuat sebagai skenario TERDOKUMENTASI di
   DATASTORE_FENCING_DESIGN.md (bukan klaim live test).

9. **QA tool repair (sesi lanjutan):** verify.py SATU ringkasan FINAL (tidak ganda),
   kategori PASS/FAIL/BLOCKED/NOT TESTED, exit code 1 hanya jika FAIL;
   tambah cek ui-overflow (UISizeConstraint), ui-hardcoded-colors, datastore-ownership,
   product-config (BLOCKED), asset-manifest; ui-audit portabel + exit code benar.
10. **Tidak diubah:** Balancing (sim tetap acuan), schema (kompatibel v1/v2), tidak ada hapus fitur,
    tidak ada Asset ID karangan, tidak ada commit/push/publish.

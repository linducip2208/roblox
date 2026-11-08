# tools/comfyui — pipeline aset lokal (ComfyUI 127.0.0.1:8188)

## File
- `check_comfyui.py` — audit server, model (SDXL Lightning 8-step), VAE, LoRA,
  upscaler, custom node inti, VRAM, direktori output.
- `generate_icons.py` — antre 8 ikon UI (512px) + update `manifest.json`.
  Lewati file yang sudah ada (aman dijalankan ulang).
- `validate_assets.py` — buka semua PNG (PIL), cek resolusi/mode/blank/duplikat,
  cocokkan manifest vs disk, cap `validated=true` TANPA mengubah status upload.
- `README.md` — file ini.
- Workflow utama batch 26 gambar: `../comfy_batch.py`.
- Workflow JSON siap-load: `../../assets/workflows/` (hanya format API).

## Aturan
- Checkpoint: `sdxl_lightning_8step.safetensors`, 8 step, cfg 1.5, euler/sgm_uniform.
- Batch 1, sequential (VRAM 8GB aman).
- Tidak ada unduhan model otomatis, tidak ada cloud API.
- Status `roblox_status` di manifest HANYA berubah manual setelah upload dashboard
  + moderasi lolos. Nilai valid: `UPLOAD_PENDING`, `UPLOADED`.

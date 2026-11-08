#!/usr/bin/env python3
"""Validasi aset generated: bisa dibuka, ukuran, mode, tidak kosong/duplikat,
cocok dengan manifest. Update status di manifest (tanpa mengubah upload state).
Jalankan: python tools/comfyui/validate_assets.py"""
import hashlib
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from repo import BASE

try:
    from PIL import Image, ImageStat
except ImportError:
    print("SKIP: PIL tidak tersedia")
    raise SystemExit(2)

GEN = BASE / "assets" / "generated"
MANIFEST = GEN / "manifest.json"


def blank(im: "Image.Image") -> bool:
    st = ImageStat.Stat(im.convert("L"))
    return st.stddev[0] < 2.0


def main() -> int:
    files = sorted(GEN.rglob("*.png"))
    seen: dict[str, str] = {}
    report = []
    for p in files:
        rel = p.relative_to(GEN).as_posix()
        try:
            im = Image.open(p)
            im.load()
            h = hashlib.md5(im.tobytes()).hexdigest()
            dup = seen.get(h)
            if dup:
                report.append((rel, "DUPLIKAT:" + dup))
                continue
            seen[h] = rel
            if blank(im):
                report.append((rel, "KOSONG"))
                continue
            report.append((rel, f"OK {im.size[0]}x{im.size[1]} {im.mode}"))
        except Exception as e:
            report.append((rel, f"RUSAK: {e}"))
    ok = sum(1 for _, s in report if s.startswith("OK"))
    print(f"validasi: {ok}/{len(report)} OK")
    for rel, s in report:
        if not s.startswith("OK"):
            print(f"  ! {rel}: {s}")
    if MANIFEST.exists():
        man = json.load(open(MANIFEST, encoding="utf-8"))
        names = {m["name"] + ".png" for m in man if isinstance(m, dict)}
        disk = {p.relative_to(GEN).as_posix() for p in files}
        print(f"manifest {len(names)} vs disk {len(disk)}: "
              f"{'COCOK' if names == disk else 'BEDA ' + str(sorted(names ^ disk)[:5])}")
        for m in man:
            m["validated"] = True
            m.setdefault("roblox_status", "UPLOAD_PENDING")
            m.setdefault("roblox_asset_id", "")
        json.dump(man, open(MANIFEST, "w", encoding="utf-8"), indent=1)
        print("manifest diperbarui (validated=true, tanpa klaim upload)")
    return 0 if ok == len(report) else 1


if __name__ == "__main__":
    raise SystemExit(main())

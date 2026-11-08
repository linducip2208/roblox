#!/usr/bin/env python3
"""Tambah UiTheme.Hover di tiap tombol yg sudah punya UiTheme.Button (idempoten)."""
import pathlib, re

BASE = pathlib.Path(__file__).resolve().parents[1]
SRC = BASE / "src" / "Client"
pat = re.compile(r"^(\s*)((?:UiTheme\w*))\.Button\(([^,)\n]+)(,[^)\n]*)?\)\s*$")
n = 0
for p in sorted(SRC.glob("*.luau")):
    lines = p.read_text(encoding="utf-8").splitlines(keepends=True)
    out = []
    for i, ln in enumerate(lines):
        out.append(ln)
        m = pat.match(ln.rstrip("\n"))
        if not m:
            continue
        nxt = lines[i + 1] if i + 1 < len(lines) else ""
        if ".Hover(" in nxt:
            continue  # sudah ada
        out.append(f"{m.group(1)}{m.group(2)}.Hover({m.group(3).strip()})\n")
        n += 1
    p.write_text("".join(out), encoding="utf-8")
print("hover ditambahkan:", n)

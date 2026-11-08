#!/usr/bin/env python3
"""Sekali jalan: ganti hardcode D:\\... di tools/*.py menjadi BASE dari repo.py."""
import pathlib, re

TOOLS = pathlib.Path(__file__).resolve().parent
OLD = r"D:\project laravel\roblox"
count = 0
for p in sorted(TOOLS.glob("*.py")):
    if p.name in ("repo.py", "port_tools.py"):
        continue
    t = p.read_text(encoding="utf-8")
    if OLD not in t:
        continue
    # 1) pastikan import repo: sisipkan setelah baris import pertama
    if "from repo import BASE" not in t:
        lines = t.splitlines(keepends=True)
        idx = next((i for i, l in enumerate(lines)
                    if l.startswith("import ") or l.startswith("from ")), 0)
        lines.insert(idx + 1, "from repo import BASE\n")
        t = "".join(lines)
    # 2) ganti literal path -> str(BASE) + sisa
    t2 = re.sub(r'r"D:\\project laravel\\roblox([^"]*)"',
                lambda m: 'str(BASE) + r"' + m.group(1) + '"', t)
    assert OLD not in t2, p.name
    p.write_text(t2, encoding="utf-8")
    count += 1
    print("patched:", p.name)
print("total:", count)

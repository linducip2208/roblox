#!/usr/bin/env python3
"""Expand mechanical one-liners (if-then-end, tiny anon callbacks) ke multi-baris.
Hanya pola paling aman. Jalankan: python tools/fix-style.py [--check]
Tanpa --check: tulis perubahan + laporkan.
"""
import pathlib, re, sys
from repo import BASE

BASE = pathlib.Path(str(BASE) + r"\src")
CHECK = "--check" in sys.argv
changed_files: list[str] = []

IF1 = re.compile(r"^(\s*)if\s+(.+?)\s+then\s+(.+?)\s+end\s*$")
CB1 = re.compile(r"^(\s*)(.*function\(\s*\)\s+)(.+?)\s+end(\s*\)?\s*,?\s*)$")

def safe_body(b: str) -> bool:
    # tolak body yg mengandung struktur/keyword berisiko
    return not re.search(r"\b(end|else|elseif|function|then|do|for|while|repeat)\b", b)

def fix_file(p: pathlib.Path) -> int:
    lines = p.read_text(encoding="utf-8").splitlines(keepends=True)
    out: list[str] = []
    n = 0
    for ln in lines:
        nl = "\n" if ln.endswith("\n") else ""
        body = ln.rstrip("\n")
        m = IF1.match(body)
        if m and safe_body(m.group(3)) and " else " not in body:
            ind, cond, stmt = m.group(1), m.group(2), m.group(3)
            out.append(f"{ind}if {cond} then\n{ind}\t{stmt}\n{ind}end{nl}")
            n += 1
            continue
        m = CB1.match(body)
        if m and safe_body(m.group(3)):
            ind, head, stmt, tail = m.group(1), m.group(2), m.group(3), m.group(4)
            out.append(f"{ind}{head}\n{ind}\t{stmt}\n{ind}end{tail}{nl}")
            n += 1
            continue
        out.append(ln)
    if n and not CHECK:
        p.write_text("".join(out), encoding="utf-8")
        changed_files.append(f"{p.name}: {n}")
    return n

total = sum(fix_file(p) for p in sorted(BASE.rglob("*.luau")))
print(("CEK " if CHECK else "") + f"selesai: {total} baris diubah")
for f in changed_files:
    print(" -", f)

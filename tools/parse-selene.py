import re, pathlib
from repo import BASE
raw = pathlib.Path(str(BASE) + r"\tools\selene-out.txt").read_bytes()
t = raw.decode("utf-16", errors="ignore") if raw.startswith(b"\xff\xfe") else raw.decode("utf-8", errors="ignore")
chunks = re.split(r"\n(?=warning\[|error\[)", t)
print(len([c for c in chunks if c.strip().startswith(("warning", "error"))]), "temuan")
for c in chunks:
    c = c.strip()
    if not c.startswith(("warning", "error")):
        continue
    head = c.split("\n")[0]
    m = re.search(r"([A-Za-z]:\\[^\n:]+):(\d+):(\d+)", c)
    loc = f"{m.group(1).split(chr(92))[-1]}:{m.group(2)}" if m else "?"
    code = c.split("\n")[2].strip() if len(c.split("\n")) > 2 else ""
    line = f"{head[:60]} | {loc} | {code[:80]}"
    print(line.encode("ascii", "replace").decode())

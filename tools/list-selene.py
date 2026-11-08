import re, pathlib, subprocess
from repo import BASE
r = subprocess.run(
    [str(BASE) + r"\tools\selene\selene.exe", str(BASE) + r"\src"],
    capture_output=True, text=True, cwd=str(BASE) + r"")
txt = r.stdout + r.stderr
chunks = re.split(r"\n(?=warning\[|error\[)", txt)
n = 0
for c in chunks:
    c = c.strip()
    if not c:
        continue
    head = c.splitlines()[0][:70]
    m = re.search(r"\\src\\(\S+?):(\d+):(\d+)", c)
    loc = f"{m.group(1)}:{m.group(2)}" if m else "?"
    code = ""
    for ln in c.splitlines()[1:]:
        if re.match(r"\s*\d+ \|", ln):
            code = ln.split("|", 1)[1].strip()[:90]
            break
    print(f"{loc} | {head} | {code}")
    n += 1
print("total:", n)

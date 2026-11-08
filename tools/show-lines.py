import pathlib
from repo import BASE
base = pathlib.Path(str(BASE) + r"")
for f, lines in [("src/Server/TreasureService.luau", [16, 97, 129, 252]),
                 ("src/Server/Main.server.luau", [284, 390, 391])]:
    t = (base / f).read_text(encoding="utf-8").splitlines()
    for n in lines:
        print(f, n, ">>>", t[n - 1][:130])

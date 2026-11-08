import pathlib, re
base = pathlib.Path(__file__).resolve().parents[1]
items = (base / "src" / "Shared" / "Items.luau").read_text(encoding="utf-8")
theme = (base / "src" / "Shared" / "UiTheme.luau").read_text(encoding="utf-8")
need = set(re.findall(r'Rarity = "(\w+)"', items))
have = set(re.findall(r"^\s*(\w+) = Color3", theme, re.M))
print("rarity item:", sorted(need))
print("tak tercover:", sorted(need - have))

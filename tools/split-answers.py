import pathlib, re
cfg = pathlib.Path(r"D:\project laravel\roblox\src\Shared\TreasureConfig.luau")
t = cfg.read_text(encoding="utf-8")
pairs = re.findall(r'\{\s*Id\s*=\s*"(R\d+)".*?Answer\s*=\s*(\d)', t, re.S)
print("riddles:", pairs)
assert len(pairs) == 10, f"expected 10, got {len(pairs)}"
# tulis modul server-only
lines = ["-- TreasureAnswers.luau — SERVER ONLY. Jangan require dari client / Shared.",
         "-- Id riddle -> index jawaban benar (1-4).",
         "return {"]
for rid, ans in pairs:
    lines.append(f'\t{rid} = {ans},')
lines.append("}")
srv = pathlib.Path(r"D:\project laravel\roblox\src\Server\TreasureAnswers.luau")
srv.write_text("\n".join(lines) + "\n", encoding="utf-8")
# hapus field Answer dari Shared (tambah komentar)
t2 = re.sub(r",?\s*Answer\s*=\s*\d,?", "", t)
t2 = t2.replace("-- Riddle: question, choices",
    "-- Riddle: question, choices (JAWABAN ADA DI Server/TreasureAnswers, JANGAN taruh di sini)")
cfg.write_text(t2, encoding="utf-8")
print("TreasureAnswers.luau ditulis, Answer dihapus dari Shared")

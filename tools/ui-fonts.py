#!/usr/bin/env python3
"""Konversi TextScaled -> TextSize + Hover konsisten (Phase 2 UI).
Jalankan: python tools/ui-fonts.py (idempoten, aman diulang)."""
import pathlib

BASE = pathlib.Path(__file__).resolve().parents[1]
SRC = BASE / "src" / "Client"

EDITS: list[tuple[str, str, str]] = [
    # TreasureUI
    ("TreasureUI.client.luau",
     'qLabel.TextScaled = true\nqLabel.TextWrapped = true',
     'qLabel.Font = Enum.Font.GothamBold\nqLabel.TextSize = 17\nqLabel.TextWrapped = true\nqLabel.TextTruncate = Enum.TextTruncate.AtEnd'),
    ("TreasureUI.client.luau",
     '\tb.TextScaled = true\n\tb.Text = "..."',
     '\tb.Font = Enum.Font.GothamBold\n\tb.TextSize = 17\n\tb.TextTruncate = Enum.TextTruncate.AtEnd\n\tb.Text = "..."'),
    ("TreasureUI.client.luau",
     'hintLabel.TextScaled = true\n',
     'hintLabel.Font = Enum.Font.GothamBold\nhintLabel.TextSize = 15\n'),
    ("TreasureUI.client.luau",
     'hintBtn.TextScaled = true\n',
     'hintBtn.Font = Enum.Font.GothamBold\nhintBtn.TextSize = 17\nhintBtn.TextTruncate = Enum.TextTruncate.AtEnd\n'),
    ("TreasureUI.client.luau",
     'compassLabel.TextScaled = true\n',
     'compassLabel.Font = Enum.Font.GothamBold\ncompassLabel.TextSize = 15\ncompassLabel.TextTruncate = Enum.TextTruncate.AtEnd\n'),
    ("TreasureUI.client.luau",
     'compassBtn.TextScaled = true\n',
     'compassBtn.Font = Enum.Font.GothamBold\ncompassBtn.TextSize = 17\ncompassBtn.TextTruncate = Enum.TextTruncate.AtEnd\n'),
    ("TreasureUI.client.luau",
     'digBtn.TextScaled = true\n',
     'digBtn.Font = Enum.Font.GothamBold\ndigBtn.TextSize = 18\ndigBtn.TextTruncate = Enum.TextTruncate.AtEnd\n'),
    ("TreasureUI.client.luau",
     'toolBtn.TextScaled = true\n',
     'toolBtn.Font = Enum.Font.GothamBold\ntoolBtn.TextSize = 16\ntoolBtn.TextTruncate = Enum.TextTruncate.AtEnd\n'),
    # InventoryUI
    ("InventoryUI.client.luau",
     'title.TextScaled = true\n',
     'title.Font = Enum.Font.GothamBold\ntitle.TextSize = 20\ntitle.TextTruncate = Enum.TextTruncate.AtEnd\n'),
    ("InventoryUI.client.luau",
     'tl.TextScaled = true\n',
     'tl.Font = Enum.Font.GothamBold\ntl.TextSize = 15\ntl.TextTruncate = Enum.TextTruncate.AtEnd\n'),
    ("InventoryUI.client.luau",
     'b.TextScaled = true\n    b.Text = text .. " (...)"',
     'b.Font = Enum.Font.GothamBold\n    b.TextSize = 17\n    b.TextTruncate = Enum.TextTruncate.AtEnd\n    b.Text = text .. " (...)"'),
    ("InventoryUI.client.luau",
     'muteBtn.TextScaled = true\n',
     'muteBtn.Font = Enum.Font.GothamBold\nmuteBtn.TextSize = 17\nmuteBtn.TextTruncate = Enum.TextTruncate.AtEnd\n'),
    # TutorialUI
    ("Tutorial.client.luau",
     'label.TextScaled = true\n',
     'label.Font = Enum.Font.GothamBold\nlabel.TextSize = 16\nlabel.TextWrapped = true\nlabel.TextTruncate = Enum.TextTruncate.AtEnd\n'),
    # Hud
    ("Hud.client.luau",
     'cashLabel.TextScaled = true\n',
     'cashLabel.Font = Enum.Font.GothamBold\ncashLabel.TextSize = 22\ncashLabel.TextTruncate = Enum.TextTruncate.AtEnd\n'),
    ("Hud.client.luau",
     'infoLabel.TextScaled = true\n',
     'infoLabel.Font = Enum.Font.Gotham\ninfoLabel.TextSize = 15\ninfoLabel.TextTruncate = Enum.TextTruncate.AtEnd\n'),
]

changed = 0
for fname, old, new in EDITS:
    p = SRC / fname
    t = p.read_text(encoding="utf-8")
    if old in t:
        p.write_text(t.replace(old, new, 1), encoding="utf-8")
        changed += 1
        print("ok:", fname, "|", old.splitlines()[0][:40])
    else:
        print("SKIP (sudah/salah):", fname, "|", old.splitlines()[0][:40])
print("total diubah:", changed)

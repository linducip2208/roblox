-- UiTheme.luau -- palet + gaya standar semua UI Steal a Kebun.
-- Panel gelap, tombol terang, teks putih, aksen kuning. Dipakai semua *UI.client.
local UiTheme = {}

UiTheme.Bg = Color3.fromRGB(28, 28, 42)
UiTheme.Btn = Color3.fromRGB(52, 52, 80)
UiTheme.Text = Color3.fromRGB(255, 255, 255)
UiTheme.Dim = Color3.fromRGB(175, 175, 195)
UiTheme.Accent = Color3.fromRGB(255, 200, 60)

function UiTheme.Panel(f: GuiObject)
	f.BackgroundColor3 = UiTheme.Bg
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
end

function UiTheme.Button(b: GuiButton)
	b.BackgroundColor3 = UiTheme.Btn
	b.BackgroundTransparency = 0
	b.TextColor3 = UiTheme.Text
	b.BorderSizePixel = 0
end

function UiTheme.Title(l: TextLabel)
	l.BackgroundTransparency = 1
	l.TextColor3 = UiTheme.Accent
end

function UiTheme.Label(l: TextLabel)
	l.BackgroundTransparency = 1
	l.TextColor3 = UiTheme.Text
end

return UiTheme

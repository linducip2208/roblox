-- UiTheme.luau -- palet + gaya standar semua UI Steal a Kebun.
-- Panel gelap, tombol terang, teks putih, aksen kuning. Dipakai semua *UI.client.
local UiTheme = {}

UiTheme.Bg = Color3.fromRGB(28, 28, 42)
UiTheme.Btn = Color3.fromRGB(52, 52, 80)
UiTheme.Text = Color3.fromRGB(255, 255, 255)
UiTheme.Dim = Color3.fromRGB(175, 175, 195)
UiTheme.Accent = Color3.fromRGB(255, 200, 60)

-- Warna per rarity: shop tidak lagi semua abu-abu.
UiTheme.Rarity = {
	Common = Color3.fromRGB(62, 62, 84),
	Uncommon = Color3.fromRGB(46, 110, 70),
	Rare = Color3.fromRGB(50, 90, 160),
	Epic = Color3.fromRGB(120, 60, 170),
	Legendary = Color3.fromRGB(170, 110, 30),
	Mythic = Color3.fromRGB(170, 40, 50),
	Event = Color3.fromRGB(30, 130, 130),
	Secret = Color3.fromRGB(20, 20, 20),
}

function UiTheme.Corner(o: GuiObject, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = o
end

function UiTheme.Stroke(o: GuiObject, color: Color3, t: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = 0.4
	s.Thickness = t or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
end

function UiTheme.Panel(f: GuiObject)
	f.BackgroundColor3 = UiTheme.Bg
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	UiTheme.Corner(f, 10)
	UiTheme.Stroke(f, Color3.fromRGB(255, 255, 255))
end

function UiTheme.Button(b: GuiButton, color: Color3?)
	b.BackgroundColor3 = color or UiTheme.Btn
	b.BackgroundTransparency = 0
	b.TextColor3 = UiTheme.Text
	b.BorderSizePixel = 0
	UiTheme.Corner(b, 8)
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

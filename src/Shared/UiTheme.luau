-- UiTheme.luau -- SATU-SATUNYA sumber gaya UI Steal a Kebun.
-- Palet resmi (jangan pakai abu-abu terang sebagai desain utama):
-- Primary #2878F0, Secondary #25B978, Gold #FFC83D, BG Navy #17243B,
-- Panel #223653, Common #7F91A8, Uncommon #27B978, Rare #348BFA,
-- Epic #A45BEB, Legendary #FFB52E, Mythic #F05269, Event #19B8B0, White #FFFFFF.
local UiTheme = {}

UiTheme.Primary = Color3.fromRGB(0x28, 0x78, 0xF0)
UiTheme.Secondary = Color3.fromRGB(0x25, 0xB9, 0x78)
UiTheme.Gold = Color3.fromRGB(0xFF, 0xC8, 0x3D)
UiTheme.Bg = Color3.fromRGB(0x17, 0x24, 0x3B)
UiTheme.Panel = Color3.fromRGB(0x22, 0x36, 0x53)
UiTheme.Text = Color3.fromRGB(0xFF, 0xFF, 0xFF)
UiTheme.DarkText = Color3.fromRGB(0x20, 0x20, 0x20)
UiTheme.Dim = Color3.fromRGB(0x9F, 0xB2, 0xCC)
UiTheme.Input = Color3.fromRGB(0x14, 0x14, 0x20)

UiTheme.Rarity = {
	Common = Color3.fromRGB(0x7F, 0x91, 0xA8),
	Uncommon = Color3.fromRGB(0x27, 0xB9, 0x78),
	Rare = Color3.fromRGB(0x34, 0x8B, 0xFA),
	Epic = Color3.fromRGB(0xA4, 0x5B, 0xEB),
	Legendary = Color3.fromRGB(0xFF, 0xB5, 0x2E),
	Mythic = Color3.fromRGB(0xF0, 0x52, 0x69),
	Event = Color3.fromRGB(0x19, 0xB8, 0xB0),
	Secret = Color3.fromRGB(0x00, 0xE5, 0xFF),
}

UiTheme.CornerRadius = 8
UiTheme.StrokeColor = Color3.fromRGB(0x3A, 0x55, 0x86)

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or UiTheme.CornerRadius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = 1
	s.Color = color or UiTheme.StrokeColor
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function padding(parent: Instance, px: number?)
	local p = Instance.new("UIPadding")
	local v = UDim.new(0, px or 8)
	p.PaddingTop, p.PaddingBottom = v, v
	p.PaddingLeft, p.PaddingRight = v, v
	p.Parent = parent
	return p
end

function UiTheme.DecoratePanel(f: GuiObject)
	f.BackgroundColor3 = UiTheme.Panel
	f.BackgroundTransparency = 0.05
	f.BorderSizePixel = 0
	corner(f)
	stroke(f)
	if f:IsA("Frame") or f:IsA("ScrollingFrame") then
		padding(f, 6)
	end
end

function UiTheme.Button(b: GuiButton, color: Color3?)
	b.BackgroundColor3 = color or UiTheme.Primary
	b.BackgroundTransparency = 0
	b.TextColor3 = UiTheme.Text
	b.Font = Enum.Font.GothamBold
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	corner(b)
end

function UiTheme.Title(l: TextLabel)
	l.BackgroundTransparency = 1
	l.TextColor3 = UiTheme.Gold
	l.Font = Enum.Font.GothamBold
end

function UiTheme.Label(l: TextLabel)
	l.BackgroundTransparency = 1
	l.TextColor3 = UiTheme.Text
	l.Font = Enum.Font.Gotham
end

function UiTheme.RarityColor(rarity: string?): Color3
	return UiTheme.Rarity[rarity or ""] or UiTheme.Common
end

-- Efek hover ringan (client only; aman dipanggil dari server karena no-op di sana).
function UiTheme.Hover(b: GuiButton)
	local ok, RunService = pcall(game.GetService, game, "RunService")
	if not ok or not RunService:IsClient() then
		return
	end
	local TweenService = game:GetService("TweenService")
	local base = b.BackgroundColor3
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	b.MouseEnter:Connect(function()
		TweenService:Create(b, info, { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.15) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, info, { BackgroundColor3 = base }):Play()
	end)
end

UiTheme.Corner = corner
UiTheme.Stroke = stroke
UiTheme.Padding = padding

return UiTheme

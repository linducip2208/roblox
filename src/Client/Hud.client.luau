-- Hud.client.luau -- cash, income/s, lock/multiplier, level + navigasi panel.
-- Navigasi memakai UiPanels (satu-satunya pengatur visibilitas).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiPanels = require(Shared:WaitForChild("UiPanels"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateHud = remotes:WaitForChild("UpdateHud")

local player = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local gui = Instance.new("ScreenGui")
gui.Name = "KebunHud"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local cashLabel = Instance.new("TextLabel")
cashLabel.AnchorPoint = Vector2.new(0, 0)
cashLabel.Size = UDim2.new(0, 300, 0, 44)
cashLabel.Position = UDim2.new(0, 16, 0, 16)
cashLabel.Font = Enum.Font.GothamBold
cashLabel.TextSize = UiTheme.FontSize.Hud
cashLabel.TextTruncate = Enum.TextTruncate.AtEnd
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.Text = "Rp 0"
cashLabel.Parent = gui
cashLabel.BackgroundColor3 = UiTheme.Bg
cashLabel.BackgroundTransparency = 0.15
cashLabel.TextColor3 = UiTheme.Text
UiTheme.Corner(cashLabel, 8)
UiTheme.Padding(cashLabel, 8)
local cashCap = Instance.new("UISizeConstraint")
cashCap.MinSize = Vector2.new(180, 44)
cashCap.MaxSize = Vector2.new(300, 44)
cashCap.Parent = cashLabel

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(0, 300, 0, 26)
infoLabel.Position = UDim2.new(0, 16, 0, 64)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = UiTheme.FontSize.Body
infoLabel.TextTruncate = Enum.TextTruncate.AtEnd
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Text = ""
infoLabel.Parent = gui
UiTheme.Label(infoLabel)
infoLabel.TextStrokeTransparency = 0.5
local infoCap = Instance.new("UISizeConstraint")
infoCap.MinSize = Vector2.new(180, 26)
infoCap.MaxSize = Vector2.new(300, 26)
infoCap.Parent = infoLabel

-- Bar navigasi bawah-tengah: di atas zona tombol HP (lompat kiri/kanan),
-- tidak menutup tengah layar, sentuh >= 44px, fit viewport 320px.
local nav = Instance.new("Frame")
nav.AnchorPoint = Vector2.new(0.5, 1)
nav.Size = UDim2.new(0, 300, 0, 48)
nav.Position = UDim2.new(0.5, 0, 1, -12)
nav.BackgroundTransparency = 1
nav.Parent = gui
local navCap = Instance.new("UISizeConstraint")
navCap.MinSize = Vector2.new(216, 48)
navCap.MaxSize = Vector2.new(300, 48)
navCap.Parent = nav
local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Horizontal
navLayout.Padding = UDim.new(0, 6)
navLayout.Parent = nav

local navBtns: { TextButton } = {}
local function navBtn(text: string, target: string)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 94, 0, 44)
	b.Font = Enum.Font.GothamBold
	b.TextSize = UiTheme.FontSize.Sub
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Text = text
	b.Parent = nav
	UiTheme.Button(b, UiTheme.Panel)
	UiTheme.Hover(b)
	b.MouseButton1Click:Connect(function()
		UiPanels.Toggle(target)
	end)
	table.insert(navBtns, b)
	return b
end

navBtn("Toko", "shop")
navBtn("Harta", "treasure")
navBtn("Profil", "profile")

-- Muat ulang ukuran HUD saat viewport berubah (320px -> desktop).
local navBaseW = 300
local function fitHud()
	local vw = UiTheme.ViewportWidth()
	local topW = math.min(300, math.max(180, vw - 32))
	cashLabel.Size = UDim2.new(0, topW, 0, 44)
	infoLabel.Size = UDim2.new(0, topW, 0, 26)
	local navW = math.min(navBaseW, math.max(216, vw - 24))
	nav.Size = UDim2.new(0, navW, 0, 48)
	local bw = math.floor((navW - 12) / 3)
	for _, b in navBtns do
		b.Size = UDim2.new(0, bw, 0, 44)
	end
end
fitHud()
local camHud = workspace.CurrentCamera
if camHud then
	camHud:GetPropertyChangedSignal("ViewportSize"):Connect(fitHud)
end

local lastCash = 0
local lastPulseAt = 0
local lastTickText = ""
local transientUntil = 0
local function showTransient(text: string, kind: string?)
	infoLabel.Text = text
	UiTheme.StyleStatus(infoLabel, kind)
	transientUntil = os.clock() + 4
	task.delay(4, function()
		if os.clock() >= transientUntil and infoLabel and infoLabel.Parent then
			infoLabel.Text = lastTickText
			UiTheme.StyleStatus(infoLabel, nil)
		end
	end)
end
UpdateHud.OnClientEvent:Connect(function(data)
	if data.type == "tick" then
		local income = tonumber(data.income) or 0
		local cash = tonumber(data.cash) or 0
		-- Pulse tiap tick naik = identitas "uang mengalir"; debounce 0.5s
		-- agar burst tick (lag/rejoin) tak menumpuk tween.
		if cash > lastCash and lastCash > 0 and os.clock() - lastPulseAt >= 0.5 then
			lastPulseAt = os.clock()
			-- pulse ringan saat uang bertambah (relatif ke ukuran responsif)
			local base = cashLabel.Size
			TweenService:Create(cashLabel, TweenInfo.new(0.12), { Size = base + UDim2.new(0, 12, 0, 2) }):Play()
			task.delay(0.12, function()
				if cashLabel and cashLabel.Parent then
					TweenService:Create(cashLabel, TweenInfo.new(0.12), { Size = base }):Play()
				end
			end)
		end
		lastCash = cash
		cashLabel.Text = "Rp " .. tostring(data.cash)
		local lock = data.locked and "[KUNCI]" or "[BUKA]"
		lastTickText = ("+%d/dtk  x%d  %s  Lv%d"):format(income, data.mult or 1, lock, data.level or 1)
		if os.clock() >= transientUntil then
			infoLabel.Text = lastTickText
			UiTheme.StyleStatus(infoLabel, nil)
		end
	elseif data.type == "welcome" then
		if data.offline and data.offline > 0 then
			showTransient(("Offline +Rp %d"):format(data.offline), "ok")
		end
	elseif data.type == "steal_ok" then
		showTransient("Berhasil curi: " .. tostring(data.itemId), "ok")
	elseif data.type == "stolen" then
		showTransient(("Kecurian! %s oleh %s"):format(tostring(data.itemId), tostring(data.by)), "error")
	elseif data.type == "steal_fail" then
		showTransient("Gagal curi: " .. tostring(data.reason), "error")
	elseif data.type == "treasure_found" then
		showTransient(("Harta %s ditemukan! Lv%d"):format(tostring(data.riddleId), tonumber(data.level) or 1), "ok")
	end
end)

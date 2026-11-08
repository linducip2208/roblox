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
local gui = Instance.new("ScreenGui")
gui.Name = "KebunHud"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local cashLabel = Instance.new("TextLabel")
cashLabel.Size = UDim2.new(0, 300, 0, 44)
cashLabel.Position = UDim2.new(0, 16, 0, 16)
cashLabel.Font = Enum.Font.GothamBold
cashLabel.TextSize = 22
cashLabel.TextTruncate = Enum.TextTruncate.AtEnd
cashLabel.Text = "Rp 0"
cashLabel.Parent = gui
cashLabel.BackgroundColor3 = UiTheme.Bg
cashLabel.BackgroundTransparency = 0.15
cashLabel.TextColor3 = UiTheme.Text
UiTheme.Corner(cashLabel, 8)

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(0, 300, 0, 26)
infoLabel.Position = UDim2.new(0, 16, 0, 64)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 15
infoLabel.TextTruncate = Enum.TextTruncate.AtEnd
infoLabel.Text = ""
infoLabel.Parent = gui
UiTheme.Label(infoLabel)
infoLabel.TextStrokeTransparency = 0.5

-- Bar navigasi bawah-kanan: sentuh >= 44px, tidak menutup tengah layar.
local nav = Instance.new("Frame")
nav.Size = UDim2.new(0, 300, 0, 48)
nav.Position = UDim2.new(1, -316, 1, -64)
nav.BackgroundTransparency = 1
nav.Parent = gui
local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Horizontal
navLayout.Padding = UDim.new(0, 6)
navLayout.Parent = nav

local function navBtn(text: string, target: string)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 94, 0, 44)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 16
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Text = text
	b.Parent = nav
	UiTheme.Button(b, UiTheme.Panel)
	b.MouseButton1Click:Connect(function()
		UiPanels.Toggle(target)
	end)
	return b
end

navBtn("Toko", "shop")
navBtn("Harta", "treasure")
navBtn("Profil", "profile")

UpdateHud.OnClientEvent:Connect(function(data)
	if data.type == "tick" then
		local income = tonumber(data.income) or 0
		cashLabel.Text = "Rp " .. tostring(data.cash)
		local lock = data.locked and "[KUNCI]" or "[BUKA]"
		infoLabel.Text = ("+%d/dtk  x%d  %s  Lv%d"):format(income, data.mult or 1, lock, data.level or 1)
	elseif data.type == "welcome" then
		if data.offline and data.offline > 0 then
			infoLabel.Text = ("Offline +Rp %d"):format(data.offline)
		end
	elseif data.type == "steal_ok" then
		infoLabel.Text = "Berhasil curi: " .. tostring(data.itemId)
	elseif data.type == "stolen" then
		infoLabel.Text = ("Kecurian! %s oleh %s"):format(tostring(data.itemId), tostring(data.by))
	elseif data.type == "steal_fail" then
		infoLabel.Text = "Gagal curi: " .. tostring(data.reason)
	elseif data.type == "treasure_found" then
		infoLabel.Text = ("Harta %s ditemukan! Lv%d"):format(tostring(data.riddleId), tonumber(data.level) or 1)
	end
end)

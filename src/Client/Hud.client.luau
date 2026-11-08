-- Hud.client.luau — tampilkan cash, multiplier, notif steal/offline
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateHud = remotes:WaitForChild("UpdateHud")

local gui = Instance.new("ScreenGui")
gui.Name = "KebunHud"
gui.ResetOnSpawn = false
gui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

local cashLabel = Instance.new("TextLabel")
cashLabel.Size = UDim2.new(0, 300, 0, 50)
cashLabel.Position = UDim2.new(0, 16, 0, 16)
cashLabel.BackgroundTransparency = 0.3
cashLabel.Text = "Rp 0"
cashLabel.TextScaled = true
cashLabel.Parent = gui
cashLabel.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
cashLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(0, 300, 0, 30)
infoLabel.Position = UDim2.new(0, 16, 0, 70)
infoLabel.Text = ""
infoLabel.TextScaled = true
infoLabel.Parent = gui
UiTheme.Label(infoLabel)
infoLabel.TextStrokeTransparency = 0.5

UpdateHud.OnClientEvent:Connect(function(data)
	if data.type == "tick" then
		cashLabel.Text = "Rp " .. tostring(data.cash)
		local lock = data.locked and "🔒" or "🔓"
		infoLabel.Text = ("x%d %s"):format(data.mult, lock)
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
	end
end)

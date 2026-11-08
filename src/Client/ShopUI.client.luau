-- ShopUI.client.luau — FULL: list dinamis + stok + timer + beli + event
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestBuy = remotes:WaitForChild("RequestBuy") :: RemoteFunction
local RequestLock = remotes:WaitForChild("RequestLock") :: RemoteEvent
local RequestRebirth = remotes:WaitForChild("RequestRebirth") :: RemoteFunction
local UpdateHud = remotes:WaitForChild("UpdateHud")
local EventState = remotes:WaitForChild("EventState")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "ShopGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("ScrollingFrame")
frame.Size = UDim2.new(0, 340, 0, 420)
frame.Position = UDim2.new(1, -360, 0, 20)
frame.CanvasSize = UDim2.new(0, 0, 0, 0)
frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
frame.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Parent = frame
layout.Padding = UDim.new(0, 6)

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0, 30)
header.Text = "🌱 SHOP (restock 5 mnt)"
header.TextScaled = true
header.Parent = frame

local eventLabel = Instance.new("TextLabel")
eventLabel.Size = UDim2.new(1, 0, 0, 30)
eventLabel.Text = "Event: -"
eventLabel.TextScaled = true
eventLabel.Parent = frame

-- tombol Lock + Rebirth
local lockBtn = Instance.new("TextButton")
lockBtn.Size = UDim2.new(1, 0, 0, 40)
lockBtn.Text = "🔒 Kunci Base (60s)"
lockBtn.TextScaled = true
lockBtn.Parent = frame
lockBtn.MouseButton1Click:Connect(function()
	RequestLock:FireServer()
end)

local rbBtn = Instance.new("TextButton")
rbBtn.Size = UDim2.new(1, 0, 0, 40)
rbBtn.Text = "♻️ Rebirth (1jt)"
rbBtn.TextScaled = true
rbBtn.Parent = frame
rbBtn.MouseButton1Click:Connect(function()
	local ok, res = RequestRebirth:InvokeServer()
	rbBtn.Text = ok and ("Rebirth x" .. tostring(res)) or ("Gagal: " .. tostring(res))
end)

local dailyBtn = Instance.new("TextButton")
dailyBtn.Size = UDim2.new(1, 0, 0, 40)
dailyBtn.Text = "🎁 Daily Reward"
dailyBtn.TextScaled = true
dailyBtn.Parent = frame
dailyBtn.MouseButton1Click:Connect(function()
	local req = remotes:WaitForChild("RequestDaily") :: RemoteFunction
	local ok, amt = req:InvokeServer()
	dailyBtn.Text = ok and ("+Rp" .. tostring(amt)) or "Sudah claim hari ini"
end)

local redeemBox = Instance.new("TextBox")
redeemBox.Size = UDim2.new(1, 0, 0, 40)
redeemBox.PlaceholderText = "Kode redeem..."
redeemBox.TextScaled = true
redeemBox.Parent = frame
redeemBox.FocusLost:Connect(function(enter)
	if not enter then return end
	local req = remotes:WaitForChild("RequestRedeem") :: RemoteFunction
	local ok, res = req:InvokeServer(redeemBox.Text)
	redeemBox.Text = ok and ("+Rp" .. tostring(res)) or ("Gagal: " .. tostring(res))
end)

-- daftar item
for _, def in Items.List do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 50)
	b.TextScaled = true
	b.Text = ("%s [%s] Rp%d -> %d/s"):format(def.Name, def.Rarity, def.Cost, def.CashPerSec)
	b.Parent = frame
	b.MouseButton1Click:Connect(function()
		local ok, res = RequestBuy:InvokeServer(def.Id)
		if ok then
			b.Text = "✅ " .. def.Name
		else
			b.Text = "❌ " .. tostring(res)
			task.delay(1.5, function()
				b.Text = ("%s [%s] Rp%d"):format(def.Name, def.Rarity, def.Cost)
			end)
		end
	end)
end

EventState.OnClientEvent:Connect(function(d)
	if d.active then
		eventLabel.Text = ("🔥 %s x2 SAMPAI %s"):format(d.name, os.date("%H:%M", d.endsAt))
	else
		eventLabel.Text = "Event: -"
	end
end)

print("Shop full loaded")

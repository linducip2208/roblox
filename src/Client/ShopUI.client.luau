-- ShopUI.client.luau — FULL: list dinamis + stok + timer + beli + event
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local UiIcons = require(Shared:WaitForChild("UiIcons"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestBuy = remotes:WaitForChild("RequestBuy") :: RemoteFunction
local RequestLock = remotes:WaitForChild("RequestLock") :: RemoteEvent
local RequestRebirth = remotes:WaitForChild("RequestRebirth") :: RemoteFunction
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
UiIcons.Attach(lockBtn, "ui-lock")

local rbBtn = Instance.new("TextButton")
rbBtn.Size = UDim2.new(1, 0, 0, 40)
rbBtn.Text = "♻️ Rebirth (1jt)"
rbBtn.TextScaled = true
rbBtn.Parent = frame
rbBtn.MouseButton1Click:Connect(function()
	local ok, res = RequestRebirth:InvokeServer()
	if ok and type(res) == "table" then
		rbBtn.Text = ("Rebirth x%d (next %s)"):format(res.rebirths, tostring(res.nextNeed))
	else
		rbBtn.Text = "Gagal: " .. tostring(res)
	end
end)
UiIcons.Attach(rbBtn, "ui-trophy")

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
UiIcons.Attach(dailyBtn, "ui-gift")

local redeemBox = Instance.new("TextBox")
redeemBox.Size = UDim2.new(1, 0, 0, 40)
redeemBox.PlaceholderText = "Kode redeem..."
redeemBox.TextScaled = true
redeemBox.Parent = frame
redeemBox.FocusLost:Connect(function(enter)
	if not enter then
		return
	end
	local req = remotes:WaitForChild("RequestRedeem") :: RemoteFunction
	local ok, res = req:InvokeServer(redeemBox.Text)
	redeemBox.Text = ok and ("+Rp" .. tostring(res)) or ("Gagal: " .. tostring(res))
end)

local RequestStock = remotes:WaitForChild("RequestStock") :: RemoteFunction
local stockLabel = Instance.new("TextLabel")
stockLabel.Size = UDim2.new(1, 0, 0, 26)
stockLabel.TextScaled = true
stockLabel.Text = "Stok: ..."
stockLabel.Parent = frame

-- daftar item (Secret disembunyikan: hanya via steal)
local itemBtns: { [string]: any } = {}
local function baseText(def)
	return ("%s [%s] Rp%d -> %d/s"):format(def.Name, def.Rarity, def.Cost, def.CashPerSec)
end
for _, def in Items.List do
	if def.Rarity == "Secret" then
		continue
	end
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 50)
	b.TextScaled = true
	b.Text = baseText(def)
	b.Parent = frame
	itemBtns[def.Id] = { btn = b, def = def }
	b.MouseButton1Click:Connect(function()
		local ok, res = RequestBuy:InvokeServer(def.Id)
		if ok then
			b.Text = "✅ " .. def.Name
			refreshStock()
		else
			b.Text = "❌ " .. tostring(res)
			task.delay(1.5, function()
				b.Text = baseText(def)
				refreshStock()
			end)
		end
	end)
end

function refreshStock()
	local ok, data = pcall(function()
		return RequestStock:InvokeServer()
	end)
	if not ok or type(data) ~= "table" then
		return
	end
	local stock = data.stock or {}
	for id, rec in itemBtns do
		local b, def = rec.btn, rec.def
		if (def :: any).EventOnly then
			b.Text = baseText(def) .. " [EVENT]"
		else
			local q = stock[id] or 0
			b.Text = baseText(def) .. (q > 0 and (" (stok %d)"):format(q) or " (HABIS)")
		end
	end
	local s = tonumber(data.secs) or 0
	stockLabel.Text = ("Restock %d:%02d"):format(math.floor(s / 60), s % 60)
end

task.spawn(function()
	while true do
		refreshStock()
		task.wait(10)
	end
end)

EventState.OnClientEvent:Connect(function(d)
	if d.active then
		eventLabel.Text = ("🔥 %s x2 SAMPAI %s"):format(d.name, os.date("%H:%M", d.endsAt))
	else
		eventLabel.Text = "Event: -"
	end
end)

print("Shop full loaded")

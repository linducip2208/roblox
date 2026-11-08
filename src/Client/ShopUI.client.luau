-- ShopUI.client.luau — FULL: list dinamis + stok + timer + beli + event
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Items"))
local UiIcons = require(Shared:WaitForChild("UiIcons"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiPanels = require(Shared:WaitForChild("UiPanels"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestBuy = remotes:WaitForChild("RequestBuy") :: RemoteFunction
local RequestLock = remotes:WaitForChild("RequestLock") :: RemoteEvent
local RequestRebirth = remotes:WaitForChild("RequestRebirth") :: RemoteFunction
local EventState = remotes:WaitForChild("EventState")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "ShopGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("ScrollingFrame")
frame.Size = UDim2.new(0, 340, 0, 420)
frame.Position = UDim2.new(1, -360, 0, 20)
frame.CanvasSize = UDim2.new(0, 0, 0, 0)
frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
frame.Parent = gui
UiTheme.DecoratePanel(frame)
local frameCap = Instance.new("UISizeConstraint")
frameCap.MaxSize = Vector2.new(380, 640)
frameCap.MinSize = Vector2.new(240, 200)
frameCap.Parent = frame

-- Tombol lipat: Shop bisa disembunyikan biar layar lega
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 44, 0, 44)
toggleBtn.Position = UDim2.new(1, -56, 0, 20)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 22
toggleBtn.Text = "X"
toggleBtn.Parent = gui
UiTheme.Button(toggleBtn, UiTheme.Bg)
UiTheme.Hover(toggleBtn)
toggleBtn.MouseButton1Click:Connect(function()
	UiPanels.Toggle("shop")
end)
UiPanels.Register("shop", function(v)
	frame.Visible = v
	toggleBtn.Text = v and "X" or "+"
end, true)
gui.Destroying:Connect(function()
	UiPanels.Unregister("shop")
end)

local layout = Instance.new("UIListLayout")
layout.Parent = frame
layout.Padding = UDim.new(0, 6)

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0, 30)
header.Text = "SHOP (restock 5 mnt)"
header.Font = Enum.Font.GothamBold
header.TextSize = 20
header.TextTruncate = Enum.TextTruncate.AtEnd
header.Parent = frame
UiTheme.Title(header)

local eventLabel = Instance.new("TextLabel")
eventLabel.Size = UDim2.new(1, 0, 0, 26)
eventLabel.Text = "Event: -"
eventLabel.Font = Enum.Font.Gotham
eventLabel.TextSize = 14
eventLabel.TextTruncate = Enum.TextTruncate.AtEnd
eventLabel.Parent = frame
UiTheme.Label(eventLabel)

-- tombol Lock + Rebirth
local lockBtn = Instance.new("TextButton")
lockBtn.Size = UDim2.new(1, 0, 0, 44)
lockBtn.Text = "Kunci Base (60s)"
lockBtn.Font = Enum.Font.GothamBold
lockBtn.TextSize = 18
lockBtn.TextTruncate = Enum.TextTruncate.AtEnd
lockBtn.Parent = frame
lockBtn.MouseButton1Click:Connect(function()
	RequestLock:FireServer()
end)
UiTheme.Button(lockBtn, UiTheme.Primary)
UiTheme.Hover(lockBtn)
UiIcons.Attach(lockBtn, "ui-lock")

local rbBtn = Instance.new("TextButton")
rbBtn.Size = UDim2.new(1, 0, 0, 44)
rbBtn.Text = "Rebirth (1jt)"
rbBtn.Font = Enum.Font.GothamBold
rbBtn.TextSize = 18
rbBtn.TextTruncate = Enum.TextTruncate.AtEnd
rbBtn.Parent = frame
rbBtn.MouseButton1Click:Connect(function()
	local ok, res = RequestRebirth:InvokeServer()
	if ok and type(res) == "table" then
		rbBtn.Text = ("Rebirth x%d (next %s)"):format(res.rebirths, tostring(res.nextNeed))
	else
		rbBtn.Text = "Gagal: " .. tostring(res)
	end
end)
UiTheme.Button(rbBtn, UiTheme.Gold)
UiTheme.Hover(rbBtn)
rbBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
UiIcons.Attach(rbBtn, "ui-trophy")

local dailyBtn = Instance.new("TextButton")
dailyBtn.Size = UDim2.new(1, 0, 0, 44)
dailyBtn.Text = "Daily Reward"
dailyBtn.Font = Enum.Font.GothamBold
dailyBtn.TextSize = 18
dailyBtn.TextTruncate = Enum.TextTruncate.AtEnd
dailyBtn.Parent = frame
dailyBtn.MouseButton1Click:Connect(function()
	local req = remotes:WaitForChild("RequestDaily") :: RemoteFunction
	local ok, amt = req:InvokeServer()
	dailyBtn.Text = ok and ("+Rp" .. tostring(amt)) or "Sudah claim hari ini"
end)
UiTheme.Button(dailyBtn, UiTheme.Secondary)
UiTheme.Hover(dailyBtn)
UiIcons.Attach(dailyBtn, "ui-gift")

local redeemBox = Instance.new("TextBox")
redeemBox.Size = UDim2.new(1, 0, 0, 44)
redeemBox.PlaceholderText = "Kode redeem..."
redeemBox.Font = Enum.Font.Gotham
redeemBox.TextSize = 16
redeemBox.TextTruncate = Enum.TextTruncate.AtEnd
redeemBox.BackgroundColor3 = Color3.fromRGB(20, 20, 32)
redeemBox.TextColor3 = UiTheme.Text
redeemBox.PlaceholderColor3 = UiTheme.Dim
redeemBox.Parent = frame
UiTheme.Corner(redeemBox, 8)
UiTheme.Stroke(redeemBox, UiTheme.Gold)
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
stockLabel.Font = Enum.Font.Gotham
stockLabel.TextSize = 14
stockLabel.TextTruncate = Enum.TextTruncate.AtEnd
stockLabel.Text = "Stok: ..."
stockLabel.Parent = frame
UiTheme.Label(stockLabel)

-- daftar item (Secret disembunyikan: hanya via steal)
local RarityCode =
	{ Common = "C", Uncommon = "U", Rare = "R", Epic = "E", Legendary = "L", Mythic = "M", Event = "Ev", Secret = "S" }
local itemBtns: { [string]: any } = {}
local function baseText(def)
	return ("%s[%s] Rp%d %d/s"):format(def.Name, RarityCode[def.Rarity] or "?", def.Cost, def.CashPerSec)
end
for _, def in Items.List do
	if def.Rarity == "Secret" then
		continue
	end
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 56)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextWrapped = true
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Text = baseText(def)
	b.Parent = frame
	UiTheme.Button(b, UiTheme.Rarity[def.Rarity])
	UiTheme.Hover(b)
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

-- InventoryUI.client.luau -- profil + gamepass/devproduct + settings suara
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestInventory = remotes:WaitForChild("RequestInventory") :: RemoteFunction

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "InventoryGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 420)
frame.Position = UDim2.new(1, -320, 0.5, -210)
frame.BackgroundTransparency = 0.15
frame.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Parent = frame
layout.Padding = UDim.new(0, 5)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.TextScaled = true
title.Text = "🎒 Profil"
title.Parent = frame

local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, 0, 0, 130)
info.TextScaled = true
info.TextWrapped = true
info.Text = "..."
info.Parent = frame

-- ID produk diambil dari server (0 = tampil "segera hadir", aman, tidak hardcode).
local ids = { gpDouble = 0, gpVip = 0, pLuck = 0, pUnlock = 0 }
local function refresh()
	local ok, d = pcall(function() 
		return RequestInventory:InvokeServer()
	end)
	if ok and type(d) == "table" then
		ids.gpDouble, ids.gpVip, ids.pLuck, ids.pUnlock =
			d.gpDouble or 0, d.gpVip or 0, d.pLuck or 0, d.pUnlock or 0
		info.Text = ("Rp%d | Rebirth x%d | Lv%d\nKunci:%d Sekop:%s Kompas:%s\nTeka-teki %d/10, Harta %d/10\nLuck:%s"):format(
			d.cash or 0, d.rebirths or 0, d.level or 1, d.keys or 0,
			(d.hasShovel and "ya" or "tdk"), (d.hasCompass and "ya" or "tdk"),
			d.riddlesSolved or 0, d.treasuresFound or 0, (d.luck and "AKTIF" or "-"))
	end
end

-- (tombol gamepass/devproduct dibuat dinamis oleh idBtn di bawah)


-- Tombol baca ID dari server saat diklik (0 = "segera hadir", tidak hardcode).
local function idBtn(text: string, key: string, isProduct: boolean)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 40)
	b.TextScaled = true
	b.Text = text .. " (...)"
	b.Parent = frame
	b.MouseButton1Click:Connect(function()
		local id = ids[key] or 0
		if id == 0 then
			b.Text = text .. " (segera hadir)"
			return
		end
		if isProduct then
			MarketplaceService:PromptProductPurchase(player, id)
		else
			MarketplaceService:PromptGamePassPurchase(player, id)
		end
	end)
	return b
end

local dynBtns = {
	{ b = idBtn("2x Uang", "gpDouble", false) },
	{ b = idBtn("VIP", "gpVip", false) },
	{ b = idBtn("Luck 15mnt", "pLuck", true) },
	{ b = idBtn("Unlock Instan", "pUnlock", true) },
}
local dynKeys = { "gpDouble", "gpVip", "pLuck", "pUnlock" }
local dynNames = { "2x Uang", "VIP", "Luck 15mnt", "Unlock Instan" }
task.spawn(function()
	while true do
		task.wait(5)
		for i, rec in dynBtns do
			local id = ids[dynKeys[i]] or 0
			rec.b.Text = dynNames[i] .. (id == 0 and " (segera hadir)" or "")
		end
	end
end)

local muteBtn = Instance.new("TextButton")
muteBtn.Size = UDim2.new(1, 0, 0, 40)
muteBtn.TextScaled = true
muteBtn.Text = "🔊 Suara: ON"
muteBtn.Parent = frame
muteBtn.MouseButton1Click:Connect(function()
	local muted = gui:GetAttribute("Muted") == true
	gui:SetAttribute("Muted", not muted)
	muteBtn.Text = (not muted) and "🔇 Suara: OFF" or "🔊 Suara: ON"
end)

task.spawn(function()
	while true do
		refresh()
		task.wait(15)
	end
end)
refresh()

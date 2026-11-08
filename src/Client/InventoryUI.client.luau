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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetMap = require(Shared:WaitForChild("AssetMap"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
UiTheme.Panel(frame)
UiTheme.Title(title)

-- Baris stat: [ikon 28px | teks]. Ikon hanya muncul bila Asset ID sudah diisi
-- (sebelum upload = teks saja, tidak ada kotak rusak).
local rows: { [string]: TextLabel } = {}
local function statRow(key: string, assetKey: string, placeholder: string)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 32)
	row.BackgroundTransparency = 1
	row.Parent = frame
	row.LayoutOrder = 10
	local iconId = AssetMap.Get(assetKey)
	if iconId then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.new(0, 28, 0, 28)
		img.Position = UDim2.new(0, 2, 0, 2)
		img.BackgroundTransparency = 1
		img.Image = iconId
		img.Parent = row
	end
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, -34, 1, 0)
	tl.Position = UDim2.new(0, 34, 0, 0)
	tl.BackgroundTransparency = 1
	tl.TextScaled = true
	tl.TextXAlignment = Enum.TextXAlignment.Left
	tl.Text = placeholder
	tl.Parent = row
	UiTheme.Label(tl)
	rows[key] = tl
end

statRow("treasure", "ui-chest", "Harta ...")
statRow("tools", "ui-shovel", "Alat ...")
statRow("luck", "ui-coin", "Uang ...")

-- ID produk diambil dari server (0 = tampil "segera hadir", aman, tidak hardcode).
local ids = { gpDouble = 0, gpVip = 0, pLuck = 0, pUnlock = 0 }
local function refresh()
	local ok, d = pcall(function()
		return RequestInventory:InvokeServer()
	end)
	if ok and type(d) == "table" then
		ids.gpDouble, ids.gpVip, ids.pLuck, ids.pUnlock = d.gpDouble or 0, d.gpVip or 0, d.pLuck or 0, d.pUnlock or 0
		rows.treasure.Text = ("Lv%d | Kunci:%d | Teka-teki %d/10, Harta %d/10"):format(
			d.level or 1,
			d.keys or 0,
			d.riddlesSolved or 0,
			d.treasuresFound or 0
		)
		rows.tools.Text = ("Sekop:%s Kompas:%s"):format(
			(d.hasShovel and "ya" or "tdk"),
			(d.hasCompass and "ya" or "tdk")
		)
		rows.luck.Text = ("Rp%d | Rebirth x%d | Luck:%s"):format(
			d.cash or 0,
			d.rebirths or 0,
			(d.luck and "AKTIF" or "-")
		)
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
	UiTheme.Button(b)
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
UiTheme.Button(muteBtn)
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

-- TreasureUI.client.luau — panel teka-teki + kompas + gali (mobile friendly)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedT = ReplicatedStorage:WaitForChild("Shared")
local UiIconsT = require(SharedT:WaitForChild("UiIcons"))
local UiThemeT = require(SharedT:WaitForChild("UiTheme"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestRiddle = remotes:WaitForChild("RequestRiddle") :: RemoteFunction
local SubmitAnswer = remotes:WaitForChild("SubmitAnswer") :: RemoteFunction
local RequestHint = remotes:WaitForChild("RequestHint") :: RemoteFunction
local CompassPing = remotes:WaitForChild("CompassPing") :: RemoteFunction
local RequestDig = remotes:WaitForChild("RequestDig") :: RemoteFunction
local BuyTool = remotes:WaitForChild("BuyTool") :: RemoteFunction

local player = Players.LocalPlayer
local currentId: string? = nil

local gui = Instance.new("ScreenGui")
gui.Name = "TreasureGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("ScrollingFrame")
frame.Size = UDim2.new(0, 340, 0, 430)
frame.Position = UDim2.new(0, 16, 0.5, -230)
frame.CanvasSize = UDim2.new(0, 0, 0, 0)
frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
frame.Parent = gui
frame.Visible = false -- default terlipat agar layar lega; buka via tombol peta
UiThemeT.Panel(frame)

-- Tombol lipat panel harta karun
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 44, 0, 44)
toggleBtn.Position = UDim2.new(0, 16, 0, 110)
toggleBtn.TextScaled = true
toggleBtn.Text = "🗺️"
toggleBtn.Parent = gui
UiThemeT.Button(toggleBtn)
toggleBtn.MouseButton1Click:Connect(function()
	frame.Visible = not frame.Visible
	toggleBtn.Text = frame.Visible and "❌" or "🗺️"
end)

local layout = Instance.new("UIListLayout")
layout.Parent = frame
layout.Padding = UDim.new(0, 6)

local qLabel = Instance.new("TextLabel")
qLabel.Size = UDim2.new(1, 0, 0, 90)
qLabel.TextScaled = true
qLabel.TextWrapped = true
qLabel.Text = "Memuat teka-teki..."
qLabel.Parent = frame
UiThemeT.Label(qLabel)

local choiceBtns = {}
for i = 1, 4 do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 44)
	b.TextScaled = true
	b.Text = "..."
	b.Parent = frame
	UiThemeT.Button(b)
	b.MouseButton1Click:Connect(function()
		local ok, res = SubmitAnswer:InvokeServer(currentId, i)
		if ok then
			qLabel.Text = ("Benar! Zona: %s +%d koin +%d kunci. Beli sekop+kompas lalu gali!"):format(
				res.Zone,
				res.RewardCash,
				res.RewardKey
			)
			refresh()
		else
			qLabel.Text = "Gagal: " .. tostring(res)
		end
	end)
	table.insert(choiceBtns, b)
end

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, 0, 0, 60)
hintLabel.TextScaled = true
hintLabel.TextWrapped = true
hintLabel.Text = ""
hintLabel.Parent = frame
UiThemeT.Label(hintLabel)

local hintBtn = Instance.new("TextButton")
hintBtn.Size = UDim2.new(1, 0, 0, 40)
hintBtn.TextScaled = true
hintBtn.Text = "💡 Minta Hint (gratis/cooldown)"
hintBtn.Parent = frame
UiThemeT.Button(hintBtn)
hintBtn.MouseButton1Click:Connect(function()
	if not currentId then
		return
	end
	local ok, res = RequestHint:InvokeServer(currentId)
	hintLabel.Text = ok and ("Hint: " .. tostring(res)) or tostring(res)
end)
UiIconsT.Attach(hintBtn, "ui-key")

local compassLabel = Instance.new("TextLabel")
compassLabel.Size = UDim2.new(1, 0, 0, 36)
compassLabel.TextScaled = true
compassLabel.Text = "Kompas: -"
compassLabel.Parent = frame
UiThemeT.Label(compassLabel)

local compassBtn = Instance.new("TextButton")
compassBtn.Size = UDim2.new(1, 0, 0, 40)
compassBtn.TextScaled = true
compassBtn.Text = "🧭 Cek Kompas"
compassBtn.Parent = frame
UiThemeT.Button(compassBtn)
compassBtn.MouseButton1Click:Connect(function()
	local ok, res = CompassPing:InvokeServer()
	compassLabel.Text = ok and ("Kompas: " .. tostring(res)) or tostring(res)
end)
UiIconsT.Attach(compassBtn, "ui-compass")

local digBtn = Instance.new("TextButton")
digBtn.Size = UDim2.new(1, 0, 0, 48)
digBtn.TextScaled = true
digBtn.Text = "⛏️ GALI DI SINI"
digBtn.Parent = frame
UiThemeT.Button(digBtn, UiThemeT.Accent)
digBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
digBtn.MouseButton1Click:Connect(function()
	local ok, res = RequestDig:InvokeServer()
	if ok then
		qLabel.Text = ("🎉 Harta %s ditemukan! Bonus +%d. Level %d"):format(res.riddleId, res.bonus, res.level)
		refresh()
	else
		qLabel.Text = "Gali gagal: " .. tostring(res)
	end
end)

local toolBtn = Instance.new("TextButton")
toolBtn.Size = UDim2.new(1, 0, 0, 40)
toolBtn.TextScaled = true
toolBtn.Text = "🛠️ Beli Sekop (5rb) / Kompas (3rb)"
toolBtn.Parent = frame
UiThemeT.Button(toolBtn)
toolBtn.MouseButton1Click:Connect(function()
	local _ok1, r1 = BuyTool:InvokeServer("shovel")
	local _ok2, r2 = BuyTool:InvokeServer("compass")
	toolBtn.Text = tostring(r1) .. " | " .. tostring(r2)
end)
UiIconsT.Attach(toolBtn, "ui-shovel")
UiIconsT.Attach(digBtn, "ui-chest")

function refresh()
	local r, err = RequestRiddle:InvokeServer()
	if r == nil then
		qLabel.Text = "🏆 Semua 10 teka-teki selesai! Tunggu event minggu depan."
		currentId = nil
		return
	end
	if r == false then
		qLabel.Text = "Memuat teka-teki... (" .. tostring(err) .. ")"
		task.delay(3, function()
			if currentId == nil then
				refresh()
			end
		end)
		return
	end
	currentId = r.Id
	qLabel.Text = ("[%s] %s"):format(r.Id, r.Q)
	for i, c in ipairs(r.Choices) do
		if choiceBtns[i] then
			choiceBtns[i].Text = ("%d. %s"):format(i, c)
		end
	end
end

refresh()

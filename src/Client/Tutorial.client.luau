-- Tutorial.client.luau — 3 langkah pertama, hanya muncul jika cash kecil + belum rebirth
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateHud = remotes:WaitForChild("UpdateHud")

local player = Players.LocalPlayer
local done = false

local gui = Instance.new("ScreenGui")
gui.Name = "TutorialGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0.9, 0, 0, 80)
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -72)
label.AutomaticSize = Enum.AutomaticSize.Y
label.Font = Enum.Font.GothamBold
label.TextSize = 16
label.TextWrapped = true
label.TextTruncate = Enum.TextTruncate.AtEnd
label.BackgroundColor3 = UiTheme.Bg
label.BackgroundTransparency = 0.15
label.TextColor3 = UiTheme.Text
label.Text = "1. Buka SHOP kanan -> beli Cabai 2. Tunggu tumbuh 3. Kunci base"
label.Parent = gui
UiTheme.Corner(label, 8)
UiTheme.Padding(label, 10)
local labelCap = Instance.new("UISizeConstraint")
labelCap.MinSize = Vector2.new(240, 60)
labelCap.MaxSize = Vector2.new(560, 200)
labelCap.Parent = label

UpdateHud.OnClientEvent:Connect(function(d)
	if done then
		return
	end
	if d.type == "tick" and d.cash and d.cash > 500 then
		done = true
		label.Text = "Mantap! Coba curi dari plot teman (tahan E) atau Rebirth di 1jt."
		task.delay(10, function()
			gui:Destroy()
		end)
	end
end)

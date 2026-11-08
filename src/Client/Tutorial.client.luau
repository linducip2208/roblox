-- Tutorial.client.luau — 3 langkah pertama, hanya muncul jika cash kecil + belum rebirth
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateHud = remotes:WaitForChild("UpdateHud")

local player = Players.LocalPlayer
local done = false

local gui = Instance.new("ScreenGui")
gui.Name = "TutorialGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Size = UDim2.new(0, 400, 0, 80)
label.Position = UDim2.new(0.5, -200, 1, -120)
label.TextScaled = true
label.TextWrapped = true
label.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
label.BackgroundTransparency = 0.15
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.Text = "1. Buka SHOP kanan -> beli Cabai 2. Tunggu tumbuh 3. Kunci base"
label.Parent = gui

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

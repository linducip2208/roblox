-- Sound.client.luau — tanpa aset upload, pakai suara bawaan Roblox
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateHud = remotes:WaitForChild("UpdateHud")

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function muted(): boolean
	local pg = player:FindFirstChildOfClass("PlayerGui")
	local inv = pg and pg:FindFirstChild("InventoryGui")
	return inv ~= nil and inv:GetAttribute("Muted") == true
end

local function beep(id: string, vol: number)
	if muted() then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 0.5
	-- parent lokal (PlayerGui): tak mereplikasi, tak mengotori workspace
	local pg = player:FindFirstChildOfClass("PlayerGui")
	s.Parent = pg or workspace
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
end

UpdateHud.OnClientEvent:Connect(function(d)
	if d.type == "steal_ok" then
		beep("rbxasset://sounds/electronicpingshort.wav", 0.7)
	elseif d.type == "stolen" then
		beep("rbxasset://sounds/impact_water.mp3", 0.7)
	elseif d.type == "welcome" and (d.offline or 0) > 0 then
		beep("rbxasset://sounds/bfsl-minifigfoots1.mp3", 0.5)
	end
end)
-- event start: dengarkan EventState
local ok, ev = pcall(function()
	return remotes:WaitForChild("EventState")
end)
if ok then
	ev.OnClientEvent:Connect(function(d)
		if d.active then
			beep("rbxasset://sounds/Rocket shot.wav", 0.5)
		end
	end)
end

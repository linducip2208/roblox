-- Sound.client.luau — tanpa aset upload, pakai suara bawaan Roblox
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateHud = remotes:WaitForChild("UpdateHud")

local function beep(id: string, vol: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 0.5
	s.Parent = workspace
	s:Play()
	s.Ended:Connect(function() s:Destroy() end)
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
local ok, ev = pcall(function() return remotes:WaitForChild("EventState") end)
if ok then
	ev.OnClientEvent:Connect(function(d)
		if d.active then beep("rbxasset://sounds/Rocket shot.wav", 0.5) end
	end)
end

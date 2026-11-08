-- StealPrompt.client.luau — tahan E 3 detik di plot orang untuk curi otomatis termahal
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestSteal = remotes:WaitForChild("RequestSteal") :: RemoteFunction

local localPlayer = Players.LocalPlayer

local function hookPlot(plot: BasePart)
	if plot.Name:match("^Plot_") == nil then return end
	if plot:FindFirstChild("StealPrompt") then return end
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "StealPrompt"
	pp.ActionText = "Curi"
	pp.ObjectText = "Tahan 3 detik"
	pp.HoldDuration = 3
	pp.MaxActivationDistance = 15
	pp.Parent = plot
	pp.Triggered:Connect(function()
		local o = plot:FindFirstChild("Owner")
		local victimId = o and tonumber(o.Value) or nil
		if not victimId then
			warn("Plot belum ada Owner UserId")
			return
		end
		if victimId == localPlayer.UserId then return end -- tidak bisa curi sendiri
		local ok, msg = RequestSteal:InvokeServer(victimId, "")
		if not ok then
			warn("Steal gagal: " .. tostring(msg))
		end
	end)
end

local plotsFolder = workspace:WaitForChild("Plots")
for _, p in plotsFolder:GetChildren() do
	if p:IsA("BasePart") then hookPlot(p) end
end
plotsFolder.ChildAdded:Connect(function(c)
	task.wait(1)
	if c:IsA("BasePart") then hookPlot(c) end
end)

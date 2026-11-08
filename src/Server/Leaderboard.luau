-- Leaderboard.luau — leaderstats Cash + Rebirths

local Leaderboard = {}

function Leaderboard.Attach(player: Player, profile)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = profile.cash or 0
	cash.Parent = ls

	local rb = Instance.new("IntValue")
	rb.Name = "Rebirths"
	rb.Value = profile.rebirths or 0
	rb.Parent = ls

	-- update tiap 2 detik dari MoneyService
	task.spawn(function()
		local MoneyService = require(script.Parent:WaitForChild("MoneyService"))
		local SaveSystem = require(script.Parent:WaitForChild("SaveSystem"))
		while player.Parent do
			task.wait(2)
			local p = SaveSystem.Get(player)
			if p then
				cash.Value = MoneyService.Get(player)
				rb.Value = p.rebirths or 0
			end
		end
	end)
end

return Leaderboard

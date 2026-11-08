-- MoneyService.luau — satu-satunya penulis cash. Semua income lewat sini.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(game.ReplicatedStorage.Shared.Config)

local MoneyService = {}
local balances: { [number]: number } = {}
local multipliers: { [number]: number } = {}

local function baseMultiplier(profile): number
	local m = 1 + (profile.rebirths * Config.RebirthMultiplierStep)
	return math.min(m, Config.MaxRebirthMultiplier)
end

function MoneyService.InitPlayer(player: Player, profile)
	balances[player.UserId] = profile.cash
	multipliers[player.UserId] = baseMultiplier(profile)
end

function MoneyService.RefreshMultiplier(player: Player, profile)
	local m = baseMultiplier(profile)
	-- 2x gamepass
	if Config.Gamepasses.DoubleMoney ~= 0 then
		local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, Config.Gamepasses.DoubleMoney)
		if ok and owns then
			m *= 2
		end
	end
	multipliers[player.UserId] = m
end

function MoneyService.Get(player: Player): number
	return balances[player.UserId] or 0
end

function MoneyService.GetMultiplier(player: Player): number
	return multipliers[player.UserId] or 1
end

-- reason dipakai untuk audit exploit. Return new balance.
function MoneyService.Add(player: Player, rawAmount: number, reason: string): number
	assert(rawAmount >= 0, "Add negatif")
	if rawAmount > Config.MaxCashPerTick * 10 then
		warn(("[Money] suspicious Add %d %s %s"):format(rawAmount, player.Name, reason))
		rawAmount = Config.MaxCashPerTick * 10
	end
	local m = MoneyService.GetMultiplier(player)
	local final = math.floor(rawAmount * m)
	balances[player.UserId] = (balances[player.UserId] or 0) + final
	return balances[player.UserId]
end

function MoneyService.Spend(player: Player, amount: number): boolean
	local b = balances[player.UserId] or 0
	if b < amount then
		return false
	end
	balances[player.UserId] = b - amount
	return true
end

function MoneyService.Set(player: Player, amount: number)
	balances[player.UserId] = amount
end

Players.PlayerRemoving:Connect(function(p)
	balances[p.UserId] = nil
	multipliers[p.UserId] = nil
end)

return MoneyService

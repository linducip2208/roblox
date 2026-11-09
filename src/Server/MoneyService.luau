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

-- Sumber tunggal rumus multiplier rebirth (dipakai Init/Refresh + kalkulasi
-- offline di SaveSystem agar tak ada duplikasi rumus yang bisa divergen).
function MoneyService.BaseMultiplier(profile): number
	return baseMultiplier(profile)
end

function MoneyService.InitPlayer(player: Player, profile)
	balances[player.UserId] = profile.cash
	multipliers[player.UserId] = baseMultiplier(profile)
end

function MoneyService.RefreshMultiplier(player: Player, profile)
	local m = baseMultiplier(profile)
	-- 2x gamepass
	if Config.Gamepasses.DoubleMoney ~= 0 then
		local ok, owns = pcall(
			MarketplaceService.UserOwnsGamePassAsync,
			MarketplaceService,
			player.UserId,
			Config.Gamepasses.DoubleMoney
		)
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

-- reason dipakai untuk audit exploit. Return new balance. Tidak pernah throw.
local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function MoneyService.Add(player: Player, rawAmount: number, reason: string): number
	if not finite(rawAmount) or rawAmount < 0 then
		warn(("[Money] Add invalid %s %s %s"):format(tostring(rawAmount), player.Name, tostring(reason)))
		return balances[player.UserId] or 0
	end
	local m = MoneyService.GetMultiplier(player)
	local final = math.floor(rawAmount * m)
	-- clamp SETELAH multiplier agar cap efektif
	local hardCap = Config.MaxCashPerTick * 10
	if final > hardCap then
		warn(("[Money] suspicious Add %d %s %s"):format(final, player.Name, tostring(reason)))
		final = hardCap
	end
	balances[player.UserId] = (balances[player.UserId] or 0) + final
	return balances[player.UserId]
end

function MoneyService.Spend(player: Player, amount: number): boolean
	if not finite(amount) or amount <= 0 then
		return false
	end
	local b = balances[player.UserId] or 0
	if b < amount then
		return false
	end
	balances[player.UserId] = b - amount
	return true
end

function MoneyService.Set(player: Player, amount: number)
	-- Satu-satunya penulis selain Add/Spend (dipakai rebirth). Validasi penuh:
	-- NaN/inf/negatif tidak boleh melahirkan saldo negatif atau NaN.
	local b = 0
	if finite(amount) then
		b = math.clamp(math.floor(amount), 0, 1e15)
	end
	balances[player.UserId] = b
end

Players.PlayerRemoving:Connect(function(p)
	balances[p.UserId] = nil
	multipliers[p.UserId] = nil
end)

return MoneyService

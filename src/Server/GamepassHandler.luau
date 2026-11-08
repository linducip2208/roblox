-- GamepassHandler.luau — prompt + efek Luck / Unlock
local MarketplaceService = game:GetService("MarketplaceService")
local Config = require(game.ReplicatedStorage.Shared.Config)

local GamepassHandler = {}
local luckUntil: { [number]: number } = {}

function GamepassHandler.HasLuck(player: Player): boolean
	if (luckUntil[player.UserId] or 0) > os.time() then
		return true
	end
	-- fallback persisten (selamat dari relog)
	local ok, SaveSystem = pcall(require, script.Parent:WaitForChild("SaveSystem"))
	if ok and SaveSystem then
		local p = SaveSystem.Get(player)
		if p and (p.luckUntil or 0) > os.time() then
			luckUntil[player.UserId] = p.luckUntil
			return true
		end
	end
	return false
end

function GamepassHandler.GrantLuck(player: Player, minutes: number)
	local expiresAt = os.time() + minutes * 60
	luckUntil[player.UserId] = expiresAt
	local ok, SaveSystem = pcall(require, script.Parent:WaitForChild("SaveSystem"))
	if ok and SaveSystem then
		local SaveSys = SaveSystem
		local p = SaveSys.Get(player)
		if p then
			p.luckUntil = expiresAt
			SaveSys.Save(player)
		end
	end
end

-- dipanggil dari Main saat ProcessReceipt DevProduct (hanya server).
-- Idempoten via PurchaseId: satu receipt tidak pernah dobel grant.
function GamepassHandler.OnProductBought(player: Player, productId: number, purchaseId: string?): boolean
	if productId ~= Config.Products.LuckBoost15m and productId ~= Config.Products.UnlockInstant then
		return false -- unknown product: tanpa hadiah
	end
	local SaveSystem = require(script.Parent:WaitForChild("SaveSystem"))
	local profile = SaveSystem.Get(player)
	if not profile then
		return false -- pemain belum loaded: NotProcessedYet agar dicoba lagi
	end
	profile.receipts = profile.receipts or {}
	if purchaseId and profile.receipts[purchaseId] then
		return true -- sudah diberi sebelumnya
	end
	if productId == Config.Products.LuckBoost15m then
		GamepassHandler.GrantLuck(player, 15)
	else
		local StealSystem = require(script.Parent:WaitForChild("StealSystem"))
		StealSystem.Unlock(player)
	end
	if purchaseId then
		profile.receipts[purchaseId] = true
	end
	SaveSystem.Save(player)
	return true
end

game.Players.PlayerRemoving:Connect(function(p)
	luckUntil[p.UserId] = nil
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasBought)
	if wasBought and passId == Config.Gamepasses.DoubleMoney then
		local SaveSystem = require(script.Parent:WaitForChild("SaveSystem"))
		local MoneyService = require(script.Parent:WaitForChild("MoneyService"))
		local p = SaveSystem.Get(player)
		if p then
			MoneyService.RefreshMultiplier(player, p)
		end
	end
end)

return GamepassHandler

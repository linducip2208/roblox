-- GamepassHandler.luau — prompt + efek Luck / Unlock
local MarketplaceService = game:GetService("MarketplaceService")
local Config = require(game.ReplicatedStorage.Shared.Config)

local GamepassHandler = {}
local luckUntil: { [number]: number } = {}

function GamepassHandler.HasLuck(player: Player): boolean
	return (luckUntil[player.UserId] or 0) > os.time()
end

function GamepassHandler.GrantLuck(player: Player, minutes: number)
	luckUntil[player.UserId] = os.time() + minutes * 60
end

-- dipanggil dari Main saat ProcessReceipt DevProduct
function GamepassHandler.OnProductBought(player: Player, productId: number)
	if productId == Config.Products.LuckBoost15m then
		GamepassHandler.GrantLuck(player, 15)
		return true
	elseif productId == Config.Products.UnlockInstant then
		local StealSystem = require(script.Parent:WaitForChild("StealSystem"))
		local SaveSystem = require(script.Parent:WaitForChild("SaveSystem"))
		local p = SaveSystem.Get(player)
		if p then
			StealSystem.LockBase(player, 0, false) -- reset lock = unlock instan versi murah
		end
		return true
	end
	return false
end

game.Players.PlayerRemoving:Connect(function(p)
	luckUntil[p.UserId] = nil
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasBought)
	if wasBought and passId == Config.Gamepasses.DoubleMoney then
		local SaveSystem = require(script.Parent:WaitForChild("SaveSystem"))
		local MoneyService = require(script.Parent:WaitForChild("MoneyService"))
		local p = SaveSystem.Get(player)
		if p then MoneyService.RefreshMultiplier(player, p) end
	end
end)

return GamepassHandler

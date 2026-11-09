-- GamepassHandler.luau — prompt + efek Luck / Unlock (SERVER ONLY).
-- Aturan: reward HANYA dari ProcessReceipt (Main) dan PromptGamePassPurchaseFinished
-- yang terverifikasi via UserOwnsGamePassAsync. TIDAK ADA Remote client yang boleh
-- memberi reward — client hanya memicu prompt Angka ID dari server (0 = nonaktif).
-- Status uji pembelian: NOT TESTED di Studio (butuh produk dashboard + sandbox).
local MarketplaceService = game:GetService("MarketplaceService")
local Config = require(game.ReplicatedStorage.Shared.Config)
local SaveSystem = require(script.Parent:WaitForChild("SaveSystem"))

local GamepassHandler = {}
local luckUntil: { [number]: number } = {}

function GamepassHandler.HasLuck(player: Player): boolean
	if (luckUntil[player.UserId] or 0) > os.time() then
		return true
	end
	-- fallback persisten (selamat dari relog)
	local p = SaveSystem.Get(player)
	if p and (p.luckUntil or 0) > os.time() then
		luckUntil[player.UserId] = p.luckUntil
		return true
	end
	return false
end

-- Hanya ubah memori + profil; TIDAK save. Caller (OnProductBought) yang commit
-- sekali agar receipt + reward atomik dalam satu Save.
function GamepassHandler.GrantLuck(player: Player, minutes: number)
	local profile = SaveSystem.Get(player)
	local base = math.max(luckUntil[player.UserId] or 0, profile and profile.luckUntil or 0, os.time())
	local expiresAt = base + minutes * 60
	luckUntil[player.UserId] = expiresAt
	if profile then
		profile.luckUntil = expiresAt
	end
end

-- dipanggil dari Main saat ProcessReceipt DevProduct (hanya server).
-- Idempoten via PurchaseId: satu receipt tidak pernah dobel grant.
-- Urutan: cek duplikat -> grant ke memori+profil -> tandai receipt -> save SEKALI.
-- Save gagal = unmark receipt + NotProcessedYet agar Roblox retry; retry grant ulang.
function GamepassHandler.OnProductBought(player: Player, productId: number, purchaseId: string?): boolean
	local luckId = Config.Products.LuckBoost15m
	local unlockId = Config.Products.UnlockInstant
	-- ID 0 = slot nonaktif: tolak tanpa grant (tanpa ack agar pembelian tak hilang).
	if productId == 0 or (luckId == 0 and unlockId == 0) then
		warn(("[Shop] produk nonaktif, tolak %d (%s)"):format(productId, player.Name))
		return false
	end
	if productId ~= luckId and productId ~= unlockId then
		warn(("[Shop] produk tak dikenal %d (%s), tunda (NotProcessedYet)"):format(productId, player.Name))
		return false -- unknown: tanpa hadiah, retry agar tidak hangus diam-diam
	end
	local profile = SaveSystem.Get(player)
	if not profile then
		return false -- pemain belum loaded: NotProcessedYet agar dicoba lagi
	end
	profile.receipts = profile.receipts or {}
	if purchaseId and profile.receipts[purchaseId] ~= nil then
		return true -- sudah diberi sebelumnya (termasuk retry setelah restart)
	end
	if purchaseId == nil then
		warn(("[Shop] PurchaseId kosong %d (%s)"):format(productId, player.Name))
	end
	if productId == luckId then
		GamepassHandler.GrantLuck(player, 15)
	else
		local StealSystem = require(script.Parent:WaitForChild("StealSystem"))
		StealSystem.Unlock(player)
	end
	if purchaseId then
		profile.receipts[purchaseId] = os.time()
	end
	-- Granted HANYA jika persistensi benar-benar commit.
	if SaveSystem.Save(player) then
		return true
	end
	-- Save gagal: cabut tanda receipt agar retry grant ulang, bukan false-ack.
	if purchaseId then
		profile.receipts[purchaseId] = nil
	end
	return false
end

game.Players.PlayerRemoving:Connect(function(p)
	luckUntil[p.UserId] = nil
end)

-- wasBought saja TIDAK cukup: verifikasi kepemilikan via API resmi sebelum
-- menerapkan efek (exploiter tidak bisa grant dari notifikasi client).
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasBought)
	if not wasBought then
		return
	end
	if passId ~= Config.Gamepasses.DoubleMoney then
		return
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	if not ok or not owns then
		warn(("[Shop] gamepass %d (%s) tak terverifikasi"):format(passId, player.Name))
		return
	end
	local MoneyService = require(script.Parent:WaitForChild("MoneyService"))
	local p = SaveSystem.Get(player)
	if p then
		MoneyService.RefreshMultiplier(player, p)
	end
end)

return GamepassHandler

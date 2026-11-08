-- ShopRotation.luau — restock ala Grow a Garden (FOMO 5 menit)
local Items = require(game.ReplicatedStorage.Shared.Items)

local ShopRotation = {}
ShopRotation.RestockInterval = 300 -- 5 menit
ShopRotation.Stock = {} -- [itemId] = qty tersisa
ShopRotation.LastRestock = os.time()

function ShopRotation.TimeLeft(): number
	local elapsed = os.time() - ShopRotation.LastRestock
	local left = ShopRotation.RestockInterval - elapsed
	if left < 0 then left = 0 end
	return left
end

local function rarityWeight(rarity: string): number
	if rarity == "Common" then return 100
	elseif rarity == "Uncommon" then return 60
	elseif rarity == "Rare" then return 30
	elseif rarity == "Epic" then return 12
	elseif rarity == "Legendary" then return 4
	elseif rarity == "Mythic" then return 2
	else return 1 -- Secret selalu langka
	end
end

function ShopRotation.Restock()
	table.clear(ShopRotation.Stock)
	for _, it in Items.List do
		-- Secret tidak masuk shop biasa, hanya dari steal/event
		if it.Rarity == "Secret" then
			continue
		end
		local w = rarityWeight(it.Rarity)
		-- semakin langka semakin sedikit stok
		local qty = math.clamp(math.floor(w / 20), 1, 5)
		if math.random(1, 100) <= w then
			ShopRotation.Stock[it.Id] = qty
		end
	end
	-- selalu ada 1 Common murah agar newbie tidak stuck
	if ShopRotation.Stock["cabai_noob"] == nil then
		ShopRotation.Stock["cabai_noob"] = 5
	end
end

function ShopRotation.IsInStock(itemId: string): boolean
	return (ShopRotation.Stock[itemId] or 0) > 0
end

function ShopRotation.Take(itemId: string): boolean
	local q = ShopRotation.Stock[itemId] or 0
	if q <= 0 then return false end
	ShopRotation.Stock[itemId] = q - 1
	return true
end

-- auto restock
task.spawn(function()
	ShopRotation.Restock()
	ShopRotation.LastRestock = os.time()
	while true do
		task.wait(ShopRotation.RestockInterval)
		ShopRotation.Restock()
		ShopRotation.LastRestock = os.time()
	end
end)

return ShopRotation

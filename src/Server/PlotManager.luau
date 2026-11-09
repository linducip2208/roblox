-- PlotManager.luau — slot tanam/panen + income tick
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.Shared.Config)
local Items = require(game.ReplicatedStorage.Shared.Items)

local PlotManager = {}
local HttpService = game:GetService("HttpService")

function PlotManager.FindFreeSlot(profile): number?
	for i = 1, Config.MaxSlots do
		if profile.slots[tostring(i)] == nil then
			return i
		end
	end
	return nil
end

function PlotManager.Plant(profile, itemId: string): (boolean, string?)
	local def = Items.ById[itemId]
	if not def then
		return false, "item_invalid"
	end
	local slot = PlotManager.FindFreeSlot(profile)
	if not slot then
		return false, "plot_penuh"
	end
	-- roll mutasi dari Config.MutationRate (bobot %); fallback aman bila tabel hilang.
	-- Urutan kumulatif dari atas: Rainbow > Dark > Gold > Normal.
	local rates = Config.MutationRate or { Normal = 70, Gold = 15, Dark = 10, Rainbow = 5 }
	local wGold = if type(rates.Gold) == "number" then rates.Gold else 15
	local wDark = if type(rates.Dark) == "number" then rates.Dark else 10
	local wRainbow = if type(rates.Rainbow) == "number" then rates.Rainbow else 5
	local tRainbow = 100 - wRainbow -- 95
	local tDark = tRainbow - wDark -- 85
	local tGold = tDark - wGold -- 70
	local roll = math.random(100)
	local mut = "Normal"
	if roll > tRainbow then
		mut = "Rainbow"
	elseif roll > tDark then
		mut = "Dark"
	elseif roll > tGold then
		mut = "Gold"
	end
	profile.slots[tostring(slot)] = {
		uid = HttpService:GenerateGUID(false),
		itemId = itemId,
		mutation = mut,
		plantedAt = os.time(),
	}
	return true, tostring(slot)
end

function PlotManager.IsGrown(slot): boolean
	local def = Items.ById[slot.itemId]
	if not def then
		return false
	end
	return (os.time() - slot.plantedAt) >= def.GrowthTime
end

function PlotManager.TickIncome(profile): number
	-- dipanggil tiap IncomeTick, return raw income (belum x multiplier)
	local sum = 0
	for _, slot in profile.slots do
		if PlotManager.IsGrown(slot) then
			local def = Items.ById[slot.itemId]
			if def then
				local m = Config.Mutations[slot.mutation] or 1
				sum += def.CashPerSec * m * Config.IncomeTick
			end
		end
	end
	if sum > Config.MaxCashPerTick then
		sum = Config.MaxCashPerTick
	end
	return math.floor(sum)
end

-- steal helpers
function PlotManager.AddStolenSlot(profile, slotData): (boolean, string?)
	local free = PlotManager.FindFreeSlot(profile)
	if not free then
		return false, "thief_penuh"
	end
	local def = Items.ById[slotData.itemId]
	if not def then
		return false, "item_invalid"
	end
	-- reset plantedAt agar tidak langsung panen duplikat exploit: anggap sudah grown
	profile.slots[tostring(free)] = {
		uid = HttpService:GenerateGUID(false),
		itemId = slotData.itemId,
		mutation = slotData.mutation or "Normal",
		plantedAt = os.time() - (def.GrowthTime + 1),
	}
	return true, tostring(free)
end

Players.PlayerRemoving:Connect(function()
	-- cleanup ringan, data asli di SaveSystem
end)

return PlotManager

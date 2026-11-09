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
	-- roll mutasi: Normal 70 / Gold 15 / Dark 10 / Rainbow 5
	local roll = math.random(100)
	local mut = "Normal"
	if roll > 95 then
		mut = "Rainbow"
	elseif roll > 85 then
		mut = "Dark"
	elseif roll > 70 then
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

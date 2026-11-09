-- InventoryService.luau — kunci, sekop, kompas. Semua mutasi lewat server.
local InventoryService = {}

function InventoryService.Ensure(profile)
	profile.treasure = profile.treasure or {}
	local t = profile.treasure
	t.solved = t.solved or {} -- [riddleId] = true
	t.found = t.found or {} -- [riddleId] = true (sudah digali)
	t.keys = t.keys or 0
	t.hasShovel = t.hasShovel or false
	t.hasCompass = t.hasCompass or false
	t.level = t.level or 1
	t.hintsUsed = t.hintsUsed or {} -- [riddleId] = count
	t.lastHintAt = t.lastHintAt or 0
	t.fails = t.fails or {} -- [riddleId] = count
	t.lockedUntil = t.lockedUntil or {} -- [riddleId] = timestamp
	return t
end

function InventoryService.GiveShovel(profile): boolean
	local t = InventoryService.Ensure(profile)
	if t.hasShovel then
		return false
	end
	t.hasShovel = true
	return true
end

function InventoryService.GiveCompass(profile): boolean
	local t = InventoryService.Ensure(profile)
	if t.hasCompass then
		return false
	end
	t.hasCompass = true
	return true
end

function InventoryService.SpendKeys(profile, n: number): boolean
	-- Tolak kuantitas non-positif: SpendKeys(p, -5) tanpa guard akan MENAMBAH kunci.
	if type(n) ~= "number" or n ~= n or n <= 0 then
		return false
	end
	local t = InventoryService.Ensure(profile)
	if t.keys < math.floor(n) then
		return false
	end
	t.keys -= math.floor(n)
	return true
end

return InventoryService

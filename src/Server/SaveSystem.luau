-- SaveSystem.luau — load/save + offline growth
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Items = require(game.ReplicatedStorage.Shared.Items)

local store = DataStoreService:GetDataStore(Config.SaveKey)
local SaveSystem = {}
local cache: { [number]: any } = {}

local function defaultProfile()
	return {
		cash = Config.StartingCash,
		rebirths = 0,
		slots = {}, -- [slotIndex string] = { uid, itemId, plantedAt }
		lastLogout = os.time(),
		offlineEarned = 0,
	}
end

local function totalCps(profile): number
	local sum = 0
	for _, slot in profile.slots do
		local def = Items.ById[slot.itemId]
		if def and os.time() - slot.plantedAt >= def.GrowthTime then
			sum += def.CashPerSec * (Config.Mutations[slot.mutation] or 1)
		end
	end
	return sum
end

function SaveSystem.Get(player: Player)
	return cache[player.UserId]
end

function SaveSystem.Load(player: Player)
	local key = "p_" .. player.UserId
	local data
	local ok, err = pcall(function()
		data = store:GetAsync(key)
	end)
	if not ok then
		warn("[Save] load gagal, pakai default: " .. tostring(err))
	end
	if type(data) ~= "table" then
		data = defaultProfile()
	end
	data.cash = data.cash or Config.StartingCash
	data.rebirths = data.rebirths or 0
	data.slots = data.slots or {}
	-- Migrasi profil lama: tambah tabel treasure + inventaris
	data.treasure = data.treasure or {}
	local t = data.treasure
	t.solved = t.solved or {}
	t.found = t.found or {}
	t.keys = t.keys or 0
	t.hasShovel = t.hasShovel or false
	t.hasCompass = t.hasCompass or false
	t.level = t.level or 1
	t.hintsUsed = t.hintsUsed or {}
	t.fails = t.fails or {}
	t.lockedUntil = t.lockedUntil or {}
	t.lastHintAt = t.lastHintAt or 0

	-- Offline growth
	local now = os.time()
	local last = tonumber(data.lastLogout) or now
	local elapsed = math.clamp(now - last, 0, Config.OfflineGrowthCap)
	local cps = totalCps(data)
	local mult = math.min(1 + data.rebirths * Config.RebirthMultiplierStep, Config.MaxRebirthMultiplier)
	local earned = math.floor(elapsed * cps * mult)
	-- cap anti kaya instan
	local cap = math.floor(Config.RebirthRequirement * Config.OfflineMaxPctOfRebirth)
	if earned > cap then
		earned = cap
	end
	data.cash += earned
	data.offlineEarned = earned
	data.lastLogout = now

	cache[player.UserId] = data
	return data
end

function SaveSystem.Save(player: Player)
	local d = cache[player.UserId]
	if not d then
		return
	end
	d.lastLogout = os.time()
	-- sinkron cash dari MoneyService agar tidak desync
	local ok, MoneyService = pcall(function()
		return require(script.Parent:WaitForChild("MoneyService"))
	end)
	if ok and MoneyService then
		local bal = MoneyService.Get(player)
		if type(bal) == "number" then
			d.cash = bal
		end
	end
	local key = "p_" .. player.UserId
	local ok2, err = pcall(function()
		store:SetAsync(key, d)
	end)
	if not ok2 then
		warn("[Save] gagal save " .. player.Name .. ": " .. tostring(err))
	end
end

-- autosave loop
task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for _, p in Players:GetPlayers() do
			SaveSystem.Save(p)
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	SaveSystem.Save(p)
	cache[p.UserId] = nil
end)

game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		SaveSystem.Save(p)
	end
	task.wait(2)
end)

return SaveSystem

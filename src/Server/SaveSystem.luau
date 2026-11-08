-- SaveSystem.luau -- load/save + offline growth + migrasi skema + retry
-- Aturan data-loss: profil yang GAGAL load TIDAK PERNAH disimpan (loadedOk=false).
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Items = require(game.ReplicatedStorage.Shared.Items)
local MoneyService = require(script.Parent.MoneyService)

local SCHEMA_VERSION = 2

local store = DataStoreService:GetDataStore(Config.SaveKey)
local sessionMap = nil
pcall(function()
	sessionMap = MemoryStoreService:GetSortedMap("KebunSessions_v1")
end)
local SaveSystem = {}
local cache: { [number]: any } = {}
local loadedOk: { [number]: boolean } = {}

local function defaultProfile()
	return {
		version = SCHEMA_VERSION,
		cash = Config.StartingCash,
		rebirths = 0,
		slots = {}, -- [slotIndex string] = { uid, itemId, mutation, plantedAt }
		dailyStreak = 0,
		lastDailyYday = "",
		redeemed = {},
		luckUntil = 0,
		treasure = nil, -- dibuat di Migrate
		lastLogout = os.time(),
		offlineEarned = 0,
	}
end

local function Migrate(data)
	if type(data.version) ~= "number" then data.version = 1 end
	-- v1 -> v2: tambah treasure, daily, redeemed, luck
	data.cash = data.cash or Config.StartingCash
	data.rebirths = data.rebirths or 0
	data.slots = data.slots or {}
	data.dailyStreak = data.dailyStreak or 0
	data.lastDailyYday = data.lastDailyYday or ""
	data.redeemed = data.redeemed or {}
	data.luckUntil = data.luckUntil or 0
	data.treasure = data.treasure or {}
	local t = data.treasure
	t.solved = t.solved or {}
	t.found = t.found or {}
	t.spots = t.spots or {}
	t.keys = t.keys or 0
	t.hasShovel = t.hasShovel or false
	t.hasCompass = t.hasCompass or false
	t.level = t.level or 1
	t.activeRiddle = t.activeRiddle
	t.hintsUsed = t.hintsUsed or {}
	t.fails = t.fails or {}
	t.lockedUntil = t.lockedUntil or {}
	t.lastHintAt = t.lastHintAt or 0
	data.version = SCHEMA_VERSION
	return data
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

function SaveSystem.IsLoaded(player: Player): boolean
	return loadedOk[player.UserId] == true
end

-- Session lock fail-open: cegah 2 server tulis data pemain yang sama.
-- Gagal total (MemoryStore down) = lanjutkan tanpa lock, JANGAN kick.
-- Return: true = boleh lanjut, false + alasan = sesi ganda aktif.
function SaveSystem.ClaimSession(player: Player): (boolean, string?)
	if sessionMap == nil then
		return true, nil
	end
	local key = "s_" .. player.UserId
	local ok, cur = pcall(function()
		return sessionMap:GetAsync(key)
	end)
	if not ok then
		return true, nil -- fail open
	end
	if type(cur) == "table" and cur.server ~= nil and cur.server ~= game.JobId then
		if (os.time() - (cur.at or 0)) < 600 then
			return false, "akun dipakai di server lain, tunggu 10 menit"
		end
		-- lock kedaluwarsa: ambil alih
	end
	pcall(function()
		sessionMap:SetAsync(key, { server = game.JobId, at = os.time() }, 660)
	end)
	return true, nil
end

function SaveSystem.ReleaseSession(player: Player)
	if sessionMap == nil then return end
	pcall(function()
		sessionMap:RemoveAsync("s_" .. player.UserId)
	end)
end

function SaveSystem.Load(player: Player)
	local key = "p_" .. player.UserId
	local data
	-- retry 3x dengan jeda; jika semua gagal -> JANGAN cache default (cegah overwrite)
	for attempt = 1, 3 do
		local ok, res = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			data = res
			break
		end
		warn(("[Save] load gagal percobaan %d %s: %s"):format(attempt, player.Name, tostring(res)))
		if attempt < 3 then task.wait(2) end
	end
	if data ~= nil and type(data) ~= "table" then
		warn("[Save] data korup, pakai default: " .. player.Name)
		data = nil
	end
	if data == nil then
		-- load benar-benar gagal ATAU pemain baru (GetAsync return nil sukses tidak dibedakan di sini).
		-- Bedakan: coba sekali lagi cepat; jika gagal lagi, tandai belum-loaded.
		local ok2 = pcall(function()
			store:GetAsync(key)
		end)
		if not ok2 then
			loadedOk[player.UserId] = false
			warn("[Save] " .. player.Name .. " BELUM loaded (DataStore down). Save dinonaktifkan.")
			return nil
		end
		data = defaultProfile()
	end
	data = Migrate(data)

	-- Offline growth
	local now = os.time()
	local last = tonumber(data.lastLogout) or now
	local elapsed = math.clamp(now - last, 0, Config.OfflineGrowthCap)
	local cps = totalCps(data)
	local mult = math.min(1 + data.rebirths * Config.RebirthMultiplierStep, Config.MaxRebirthMultiplier)
	local earned = math.floor(elapsed * cps * mult)
	local cap = math.floor(Config.RebirthRequirementFor(data.rebirths or 0) * Config.OfflineMaxPctOfRebirth)
	if earned > cap then
		earned = cap
	end
	data.cash += earned
	data.offlineEarned = earned
	data.lastLogout = now

	cache[player.UserId] = data
	loadedOk[player.UserId] = true
	return data
end

-- Salin bersih untuk DataStore (buang field transient _uid).
local function snapshot(profile)
	local copy = {}
	for k, v in profile do
		if k ~= "_uid" and k ~= "offlineEarned" then
			copy[k] = v
		end
	end
	return copy
end

function SaveSystem.Save(player: Player)
	local d = cache[player.UserId]
	if not d then return end
	if not loadedOk[player.UserId] then
		warn("[Save] skip save (belum loaded): " .. player.Name)
		return
	end
	d.lastLogout = os.time()
	local bal = MoneyService.Get(player)
	if type(bal) == "number" then
		d.cash = bal
	end
	local key = "p_" .. player.UserId
	local snap = snapshot(d)
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:SetAsync(key, snap)
		end)
		if ok then return end
		warn(("[Save] save gagal percobaan %d %s: %s"):format(attempt, player.Name, tostring(err)))
		if attempt < 3 then task.wait(2) end
	end
end

-- autosave loop (hanya profil yang loadedOk)
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
	SaveSystem.ReleaseSession(p)
	cache[p.UserId] = nil
	loadedOk[p.UserId] = nil
end)

game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		SaveSystem.Save(p)
		SaveSystem.ReleaseSession(p)
	end
	task.wait(8)
end)

return SaveSystem

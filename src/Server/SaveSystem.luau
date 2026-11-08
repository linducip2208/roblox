-- SaveSystem.luau -- load/save + migrasi skema + session lock + envelope aman
-- Kebijakan: FAIL-CLOSED. Tanpa lock sesi yang pasti, pemain tidak boleh main.
-- Tanpa load sukses, tidak ada save (tidak pernah timpa data dengan default).
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Items = require(game.ReplicatedStorage.Shared.Items)
local MoneyService = require(script.Parent.MoneyService)

local SCHEMA_VERSION = 2
local LOCK_TTL = 300 -- detik; heartbeat tiap 60
local PROFILE_KEY_PREFIX = "p_"
local SESSION_KEY_PREFIX = "s_"

local store = DataStoreService:GetDataStore(Config.SaveKey)
local sessionMap = nil
pcall(function()
	sessionMap = MemoryStoreService:GetSortedMap("KebunSessions_v1")
end)

local SaveSystem = {}
local cache: { [number]: any } = {}
local loadedOk: { [number]: boolean } = {}
local sessionToken: { [number]: string } = {}
local savedOnLeave: { [number]: boolean } = {}

local function now(): number
	return os.time()
end

local function backoff(attempt: number)
	task.wait(math.random(80, 120) / 100 * math.pow(2, attempt - 1))
end

-- ============ VALIDASI ============
local function num(v: any, default: number, min: number?, max: number?): number
	if type(v) ~= "number" or v ~= v then -- NaN check (v ~= v)
		return default
	end
	if v == math.huge or v == -math.huge then
		return default
	end
	if min ~= nil and v < min then
		return default
	end
	if max ~= nil and v > max then
		return default
	end
	return v
end

local function ValidateProfile(d: any)
	if type(d) ~= "table" then
		return nil
	end
	d.version = SCHEMA_VERSION
	d.cash = num(d.cash, Config.StartingCash, 0, 1e15)
	d.rebirths = math.floor(num(d.rebirths, 0, 0, 1000))
	d.slots = if type(d.slots) == "table" then d.slots else {}
	-- sanitasi slot: buang entri rusak, clamp waktu
	for k, slot in d.slots do
		if
			type(slot) ~= "table"
			or type(slot.itemId) ~= "string"
			or Items.ById[slot.itemId] == nil
			or type(slot.plantedAt) ~= "number"
		then
			d.slots[k] = nil
		else
			slot.plantedAt = math.clamp(slot.plantedAt, 0, now())
			if type(slot.mutation) ~= "string" or Config.Mutations[slot.mutation] == nil then
				slot.mutation = "Normal"
			end
		end
	end
	d.dailyStreak = math.floor(num(d.dailyStreak, 0, 0, 7))
	d.lastDailyYday = if type(d.lastDailyYday) == "string" then d.lastDailyYday else ""
	d.redeemed = if type(d.redeemed) == "table" then d.redeemed else {}
	-- receipts: PurchaseId -> timestamp. Prune >30 hari agar tidak tumbuh tanpa batas
	-- (retry Roblox terjadi dalam hitungan hari, bukan bulan).
	d.receipts = if type(d.receipts) == "table" then d.receipts else {}
	do
		local count = 0
		for _ in d.receipts do
			count += 1
		end
		if count > 200 then
			local cutoff = now() - 30 * 86400
			for pid, at in d.receipts do
				if type(at) ~= "number" or at < cutoff then
					d.receipts[pid] = nil
				end
			end
		end
	end
	d.luckUntil = num(d.luckUntil, 0, 0, now() + 86400 * 30)
	d.treasure = if type(d.treasure) == "table" then d.treasure else {}
	local t = d.treasure
	t.solved = if type(t.solved) == "table" then t.solved else {}
	t.found = if type(t.found) == "table" then t.found else {}
	t.spots = if type(t.spots) == "table" then t.spots else {}
	t.keys = math.floor(num(t.keys, 0, 0, 9999))
	t.hasShovel = t.hasShovel == true
	t.hasCompass = t.hasCompass == true
	t.level = math.floor(num(t.level, 1, 1, 9999))
	t.hintsUsed = if type(t.hintsUsed) == "table" then t.hintsUsed else {}
	t.fails = if type(t.fails) == "table" then t.fails else {}
	t.lockedUntil = if type(t.lockedUntil) == "table" then t.lockedUntil else {}
	t.lastHintAt = num(t.lastHintAt, 0, 0, now())
	return d
end

local function defaultProfile()
	return ValidateProfile({
		version = SCHEMA_VERSION,
		cash = Config.StartingCash,
		rebirths = 0,
		slots = {},
		dailyStreak = 0,
		lastDailyYday = "",
		redeemed = {},
		luckUntil = 0,
		treasure = {},
		lastLogout = now(),
		offlineEarned = 0,
	})
end

local function totalCps(profile): number
	local sum = 0
	for _, slot in profile.slots do
		local def = Items.ById[slot.itemId]
		if def and now() - slot.plantedAt >= def.GrowthTime then
			sum += def.CashPerSec * (Config.Mutations[slot.mutation] or 1)
		end
	end
	return sum
end

-- ============ SESSION LOCK (atomik, fail-closed + mode ephemeral Studio) ============
-- Akuisisi via UpdateAsync: transform atomik, hanya menang jika kosong/kedaluwarsa/milik sendiri.
-- Pengecualian: Studio unpublished tidak punya MemoryStore/DataStore. Jika dipaksa
-- fail-closed, game TIDAK BISA di-Play-test lokal sama sekali. Maka di Studio saja:
-- beri lock ephemeral (memori saja, tidak pernah sentuh DataStore). Aman karena
-- RunService:IsStudio() tidak bisa dipalsukan exploiter di server produksi.
function SaveSystem.ClaimSession(player: Player): (boolean, string?)
	if sessionMap == nil then
		if RunService:IsStudio() then
			warn("[Save] Mode EPHEMERAL (Studio tanpa MemoryStore): progres sesi ini saja.")
			sessionToken[player.UserId] = "STUDIO_EPHEMERAL"
			return true, nil
		end
		return false, "lock_unavailable_coba_lagi"
	end
	local uid = player.UserId
	local token = HttpService:GenerateGUID(false)
	local myLock = { job = game.JobId, token = token, at = now(), exp = now() + LOCK_TTL }
	for attempt = 1, 3 do
		local ok, res = pcall(function()
			return sessionMap:UpdateAsync(SESSION_KEY_PREFIX .. uid, function(old)
				if old == nil then
					return myLock
				end
				if type(old) ~= "table" then
					return myLock
				end
				if old.job == game.JobId then
					return myLock -- server sama, ambil alih (restart/shutdown)
				end
				if (old.exp or 0) < now() then
					return myLock -- kedaluwarsa
				end
				return old -- sesi lain masih hidup: TOLAK
			end, LOCK_TTL)
		end)
		if ok and type(res) == "table" and res.token == token then
			sessionToken[uid] = token
			return true, nil
		elseif ok and type(res) == "table" then
			return false, "akun dipakai di server lain (tunggu maks 5 mnt)"
		end
		backoff(attempt)
	end
	return false, "lock_unavailable_coba_lagi"
end

function SaveSystem.ReleaseSession(player: Player)
	local uid = player.UserId
	local mine = sessionToken[uid]
	sessionToken[uid] = nil
	if sessionMap == nil or mine == nil then
		return
	end
	pcall(function()
		sessionMap:UpdateAsync(SESSION_KEY_PREFIX .. uid, function(old)
			if type(old) == "table" and old.token == mine then
				return nil -- hapus hanya milik sendiri
			end
			return old -- milik orang lain: jangan sentuh
		end)
	end)
end

-- Verifikasi ulang lock SEBELUM commit (jangan andalkan status lama).
-- Fail-closed: lock hilang/diambil alih/tidak bisa dicek = JANGAN simpan.
function SaveSystem.VerifyLock(player: Player): (boolean, string?)
	local mine = sessionToken[player.UserId]
	if mine == nil or sessionMap == nil then
		return false, "no_session"
	end
	local ok, cur = pcall(function()
		return sessionMap:GetAsync(SESSION_KEY_PREFIX .. player.UserId)
	end)
	if not ok then
		return false, "lock_unavailable"
	end
	if type(cur) == "table" and cur.token == mine and (cur.exp or 0) > now() then
		return true, nil
	end
	return false, "lock_lost"
end

function SaveSystem.DropCache(player: Player)
	local uid = player.UserId
	cache[uid] = nil
	loadedOk[uid] = nil
	sessionToken[uid] = nil
	savedOnLeave[uid] = nil
end

-- Heartbeat: perpanjang lock milik sendiri tiap 60 dtk. Mismatch = sesi diambil alih -> kick.
task.spawn(function()
	while true do
		task.wait(60)
		for _, p in Players:GetPlayers() do
			local mine = sessionToken[p.UserId]
			if mine ~= nil and sessionMap ~= nil then
				local ok, res = pcall(function()
					return sessionMap:UpdateAsync(SESSION_KEY_PREFIX .. p.UserId, function(old)
						if type(old) == "table" and old.token == mine then
							old.at = now()
							old.exp = now() + LOCK_TTL
							return old
						end
						return old
					end, LOCK_TTL)
				end)
				if ok and (type(res) ~= "table" or res.token ~= mine) then
					-- lock hilang/diambil alih: hentikan sesi ini agar tidak merusak data
					warn("[Save] session diambil alih, kick: " .. p.Name)
					pcall(function()
						p:Kick("Sesi dipindahkan. Join lagi.")
					end)
				end
			end
		end
	end
end)

-- ============ LOAD / SAVE ============
function SaveSystem.Get(player: Player)
	return cache[player.UserId]
end

function SaveSystem.IsLoaded(player: Player): boolean
	return loadedOk[player.UserId] == true
end

-- Klasifikasi error DataStore agar diagnosis jelas (op + jenis).
local function classifyError(err: any): string
	local msg = string.lower(tostring(err))
	if string.find(msg, "throttl", 1, true) then
		return "throttled"
	end
	if string.find(msg, "timeout", 1, true) or string.find(msg, "timed out", 1, true) then
		return "timeout"
	end
	if string.find(msg, "not allowed", 1, true) or string.find(msg, "studio", 1, true) then
		return "api_disabled"
	end
	return "unavailable"
end

-- Envelope: {v, session, at, data}. Tolak timpa jika cloud lebih baru dari server lain.
-- Return: data | nil, errKind | nil. errKind = throttled/timeout/api_disabled/unavailable.
local function readEnvelope(key: string): any
	local lastErr: any = nil
	for attempt = 1, 3 do
		local ok, res = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			return res, nil
		end
		lastErr = res
		warn(("[Save] Load:GetAsync gagal (%s) percobaan %d"):format(classifyError(res), attempt))
		backoff(attempt)
	end
	return nil, classifyError(lastErr)
end

function SaveSystem.Load(player: Player)
	-- Mode ephemeral Studio: lewati DataStore sepenuhnya, profil fresh per sesi.
	if sessionToken[player.UserId] == "STUDIO_EPHEMERAL" then
		local data = defaultProfile()
		data.offlineEarned = 0
		cache[player.UserId] = data
		loadedOk[player.UserId] = true
		return data
	end
	local key = PROFILE_KEY_PREFIX .. player.UserId
	local env, err = readEnvelope(key)
	if env == nil and err ~= nil then
		local kind = err or "unavailable"
		loadedOk[player.UserId] = false
		warn(
			("[Save] %s BELUM loaded (Load:GetAsync %s). Save dinonaktifkan, TIDAK pakai default."):format(
				player.Name,
				kind
			)
		)
		return nil
	end
	-- Pemain baru = key kosong (GetAsync sukses, nil). Legacy v1 = tabel mentah berisi cash/slots.
	-- Bentuk lain = korup -> TOLAK (jangan timpa dengan default).
	local data = nil
	local baseAt, baseSession = 0, nil
	if env == nil then
		data = defaultProfile()
	elseif type(env) == "table" and env.data ~= nil then
		data = ValidateProfile(env.data)
		baseAt, baseSession = (env.at or 0), env.session
		if data == nil then
			loadedOk[player.UserId] = false
			warn("[Save] data korup (validasi gagal): " .. player.Name)
			return nil
		end
	elseif type(env) == "table" and (env.cash ~= nil or env.slots ~= nil) then
		data = ValidateProfile(env) -- migrasi legacy v1 mentah
		warn("[Save] migrasi profil legacy v1: " .. player.Name)
	else
		loadedOk[player.UserId] = false
		warn("[Save] envelope tak dikenal (kemungkinan korup), TOLAK load: " .. player.Name)
		return nil
	end
	if player.Parent == nil then -- disconnect saat load
		return nil
	end
	-- catat basis versi untuk deteksi konflik saat save
	data._baseAt = baseAt
	data._baseSession = baseSession

	-- Offline growth
	local last = num(data.lastLogout, now(), 0, now())
	local elapsed = math.clamp(now() - last, 0, Config.OfflineGrowthCap)
	local cps = totalCps(data)
	local mult = math.min(1 + data.rebirths * Config.RebirthMultiplierStep, Config.MaxRebirthMultiplier)
	local earned = math.floor(elapsed * cps * mult)
	local cap = math.floor(Config.RebirthRequirementFor(data.rebirths or 0) * Config.OfflineMaxPctOfRebirth)
	if earned > cap then
		earned = cap
	end
	data.cash += earned
	data.offlineEarned = earned
	data.lastLogout = now()

	cache[player.UserId] = data
	loadedOk[player.UserId] = true
	return data
end

local function snapshot(profile)
	local copy = {}
	for k, v in profile do
		if k ~= "_uid" and k ~= "_baseAt" and k ~= "_baseSession" and k ~= "offlineEarned" then
			copy[k] = v
		end
	end
	return copy
end

function SaveSystem.Save(player: Player): boolean
	local d = cache[player.UserId]
	if not d then
		return false
	end
	if not loadedOk[player.UserId] then
		warn("[Save] skip save (belum loaded): " .. player.Name)
		return false
	end
	if sessionToken[player.UserId] == nil then
		warn("[Save] skip save (tanpa session lock): " .. player.Name)
		return false
	end
	if sessionToken[player.UserId] == "STUDIO_EPHEMERAL" then
		return true -- sesi lokal Studio: anggap tersimpan (memori), tanpa tulis DataStore
	end
	local lockOk, lockErr = SaveSystem.VerifyLock(player)
	if not lockOk then
		warn(("[Save] skip save (lock %s): %s"):format(tostring(lockErr), player.Name))
		return false
	end
	d.lastLogout = now()
	local bal = MoneyService.Get(player)
	if type(bal) == "number" then
		d.cash = bal
	end
	local snap = snapshot(ValidateProfile(d) or d)
	local mySession = game.JobId
	local baseAt = d._baseAt or 0
	local baseSession = d._baseSession
	local key = PROFILE_KEY_PREFIX .. player.UserId
	for attempt = 1, 3 do
		local ok, res = pcall(function()
			return store:UpdateAsync(key, function(old)
				if type(old) == "table" and old.at ~= nil and old.data ~= nil then
					-- cloud lebih baru dari basis kita DAN dari sesi lain -> JANGAN timpa
					if old.at > baseAt and old.session ~= mySession and old.session ~= baseSession then
						return old
					end
				end
				return { v = SCHEMA_VERSION, session = mySession, at = now(), data = snap }
			end)
		end)
		if ok and type(res) == "table" and res.session == mySession then
			d._baseAt = res.at
			d._baseSession = mySession
			return true
		end
		if ok then
			warn("[Save] konflik versi, skip save: " .. player.Name)
			return false
		end
		backoff(attempt)
	end
	warn("[Save] save gagal 3x: " .. player.Name)
	return false
end

-- autosave stagger: jeda antar pemain agar tidak spike
task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for _, p in Players:GetPlayers() do
			SaveSystem.Save(p)
			task.wait(0.5)
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	if not savedOnLeave[p.UserId] then
		savedOnLeave[p.UserId] = true
		SaveSystem.Save(p)
	end
	SaveSystem.ReleaseSession(p)
	cache[p.UserId] = nil
	loadedOk[p.UserId] = nil
end)

game:BindToClose(function()
	-- paralel agar 8 pemain selesai sebelum batas shutdown
	local done = 0
	local list = Players:GetPlayers()
	for _, p in list do
		task.spawn(function()
			if not savedOnLeave[p.UserId] then
				savedOnLeave[p.UserId] = true
				SaveSystem.Save(p)
				SaveSystem.ReleaseSession(p)
			end
			done += 1
		end)
	end
	local waited = 0
	while done < #list and waited < 25 do
		task.wait(0.5)
		waited += 0.5
	end
end)

return SaveSystem

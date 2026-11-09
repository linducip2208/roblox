-- SaveSystem.luau -- load/save + migrasi skema + session lock + fencing generation + envelope aman
-- Kebijakan: FAIL-CLOSED. Tanpa lock sesi yang pasti, pemain tidak boleh main.
-- Tanpa load sukses, tidak ada save (tidak pernah timpa data dengan default).
-- FENCING: setiap sesi mengakuisisi generation monotonik via DataStore UpdateAsync
-- atomik SEBELUM load. Transform save menolak generation basi & identitas sesi basi
-- SECARA ATOMIK di dalam callback. MemoryStore hanya lapis lease tambahan, BUKAN
-- satu-satunya sumber kebenaran otorisasi tulis durable (lihat DATASTORE_FINAL_DESIGN.md).
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local Items = require(game.ReplicatedStorage.Shared.Items)
local MoneyService = require(script.Parent.MoneyService)
local Analytics = require(script.Parent.Analytics)

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
local sessionGen: { [number]: number } = {}
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
			if count > 200 then
				break -- cukup tahu melebihi batas, hemat hitung
			end
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
-- Akuisisi via UpdateAsync: transform atomik, hanya menang jika kosong/kedaluwarsa.
-- JobId SAMA tanpa token yang cocok TIDAK cukup untuk takeover: token baru tidak
-- membuktikan kepemilikan sesi lama (sesi kedaluwarsa pun harus menunggu exp).
-- Renew milik sendiri ditangani heartbeat (perbandingan token persis), bukan claim.
-- Studio SELALU ephemeral (memori saja, tidak pernah sentuh DataStore) agar data uji
-- lokal tidak pernah menulis profil palsu ke produksi. Aman karena
-- RunService:IsStudio() tidak bisa dipalsukan exploiter di server produksi.
function SaveSystem.ClaimSession(player: Player): (boolean, string?)
	if RunService:IsStudio() then
		warn("[Save] Mode EPHEMERAL (Studio): progres sesi ini saja, tanpa tulis DataStore.")
		sessionToken[player.UserId] = "STUDIO_EPHEMERAL"
		savedOnLeave[player.UserId] = nil
		return true, nil
	end
	if sessionMap == nil then
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
				if (old.exp or 0) < now() then
					return myLock -- kedaluwarsa (syarat SATU-SATUNYA untuk ambil alih)
				end
				return old -- sesi lain masih hidup: TOLAK, walau JobId sama
			end, LOCK_TTL)
		end)
		if ok and type(res) == "table" and res.token == token then
			sessionToken[uid] = token
			savedOnLeave[uid] = nil -- rejoin server sama: izinkan autosave/leave-save lagi
			return true, nil
		elseif ok and type(res) == "table" then
			return false, "akun dipakai di server lain (tunggu maks 5 mnt)"
		end
		if attempt < 3 then
			backoff(attempt)
		end
	end
	return false, "lock_unavailable_coba_lagi"
end

function SaveSystem.ReleaseSession(player: Player)
	local uid = player.UserId
	local mine = sessionToken[uid]
	sessionToken[uid] = nil
	sessionGen[uid] = nil
	if sessionMap == nil or mine == nil or mine == "STUDIO_EPHEMERAL" then
		return -- ephemeral Studio tidak pernah memegang lock MemoryStore
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
	sessionGen[uid] = nil
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

-- Normalisasi identitas sesi: string lama (hanya JobId) -> tabel {job, token}.
-- Perbandingan SELALU lewat tabel agar token ikut diverifikasi, bukan cuma JobId.
function SaveSystem.NormalizeSession(s: any): { job: string?, token: string? }
	if type(s) == "table" then
		return { job = s.job, token = s.token }
	end
	return { job = if type(s) == "string" then s else nil, token = nil }
end

-- Envelope: {v, gen, session, at, data}. `gen` = fencing generation monotonik per
-- profil, naik +1 atomik tiap sesi BARU mengakuisisi (di dalam transform
-- UpdateAsync). Sesi menyimpan gen miliknya; transform save menolak tulisan dengan
-- gen basi / identitas sesi basi SECARA ATOMIK, sehingga TOCTOU VerifyLock lalu
-- tulis tidak mungkin terjadi: kepemilikan bisa berpindah di antara keduanya, tapi
-- transform selalu memutuskan berdasarkan nilai cloud TERKINI.
-- Return: data | nil, errKind | nil. errKind = throttled/timeout/api_disabled/unavailable/corrupt.
local function newEnvelope(gen: number, session: { job: string?, token: string? }, data: any): any
	return {
		v = SCHEMA_VERSION,
		gen = gen,
		session = { job = session.job, token = session.token },
		at = now(),
		data = data,
	}
end

-- Salinan profil tanpa field runtime (tidak disimpan ke DataStore).
local function stripRuntime(profile): any
	local copy = {}
	for k, v in profile do
		if k ~= "_uid" and k ~= "_baseAt" and k ~= "_baseSession" and k ~= "_baseGen" and k ~= "offlineEarned" then
			copy[k] = v
		end
	end
	return copy
end

-- Akuisisi fencing + baca atomik: SATU UpdateAsync yang (a) menaikkan gen untuk sesi
-- baru, (b) memigrasi legacy v1 mentah, (c) mengembalikan data terkini untuk load.
-- Callback deterministik & tanpa side-effect eksternal: hanya bangun tabel dari
-- `old` + argumen. Abort (return nil) = TOLAK tulis: korup/legacy-takdikenal tidak
-- pernah ditimpa; caller fail-closed (tidak init default setelah load gagal).
-- Re-fence sesi sendiri idempoten: gen TIDAK naik bila session == milik kita.
local function fenceAndRead(key: string, mySession: { job: string?, token: string? }): (any, string?)
	local lastErr: any = nil
	for attempt = 1, 3 do
		local ok, res = pcall(function()
			return store:UpdateAsync(key, function(old)
				if old == nil then
					-- Pemain baru (key kosong, UpdateAsync sukses): init default + gen 1.
					return newEnvelope(1, mySession, stripRuntime(defaultProfile()))
				end
				if type(old) ~= "table" then
					return nil -- korup: ABORT, jangan timpa
				end
				if old.data ~= nil then
					local oldS = SaveSystem.NormalizeSession(old.session)
					if oldS.job == mySession.job and oldS.token == mySession.token then
						return old -- re-fence sendiri: idempoten
					end
					local data = ValidateProfile(old.data)
					if data == nil then
						return nil -- korup: ABORT
					end
					local gen = if type(old.gen) == "number" then old.gen else 0
					old.gen = gen + 1
					old.session = { job = mySession.job, token = mySession.token }
					old.at = now()
					old.v = SCHEMA_VERSION
					return old
				end
				if old.cash ~= nil or old.slots ~= nil then
					-- Migrasi legacy v1 mentah -> envelope bergen, atomik.
					local data = ValidateProfile(old)
					if data == nil then
						return nil -- ABORT
					end
					return newEnvelope(1, mySession, stripRuntime(data))
				end
				return nil -- envelope tak dikenal (kemungkinan korup): ABORT
			end)
		end)
		if ok then
			if res == nil then
				return nil, "corrupt"
			end
			return res, nil
		end
		lastErr = res
		warn(("[Save] Fence:UpdateAsync gagal (%s) percobaan %d"):format(classifyError(res), attempt))
		if attempt < 3 then
			backoff(attempt)
		end
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
	local mine = sessionToken[player.UserId]
	if mine == nil then
		loadedOk[player.UserId] = false
		warn("[Save] Load ditolak (tanpa session lock): " .. player.Name)
		return nil
	end
	local mySession = { job = game.JobId, token = mine }
	local key = PROFILE_KEY_PREFIX .. player.UserId
	-- Akuisisi generation valid SEBELUM mutasi apa pun; gagal = fail-closed.
	local env, err = fenceAndRead(key, mySession)
	if env == nil then
		local kind = err or "unavailable"
		loadedOk[player.UserId] = false
		warn(
			("[Save] %s BELUM loaded (Fence:UpdateAsync %s). Save dinonaktifkan, TIDAK pakai default."):format(
				player.Name,
				kind
			)
		)
		return nil
	end
	if type(env.data) ~= "table" then
		loadedOk[player.UserId] = false
		warn("[Save] envelope tanpa data (kemungkinan korup), TOLAK load: " .. player.Name)
		return nil
	end
	-- Pemain baru = key kosong saat fence (default+gen 1 tertulis atomik).
	-- Legacy v1 mentah sudah dimigrasi atomik di dalam fence. Korup = fence ABORT.
	local data = ValidateProfile(env.data)
	if data == nil then
		loadedOk[player.UserId] = false
		warn("[Save] data korup (validasi gagal): " .. player.Name)
		return nil
	end
	if player.Parent == nil then -- disconnect saat load
		loadedOk[player.UserId] = false
		return nil
	end
	-- catat basis versi + fencing untuk deteksi konflik saat save
	sessionGen[player.UserId] = if type(env.gen) == "number" then env.gen else 0
	data._baseAt = env.at or 0
	data._baseSession = SaveSystem.NormalizeSession(env.session) -- string lama atau tabel baru
	data._baseGen = sessionGen[player.UserId]

	-- Offline growth
	local last = num(data.lastLogout, now(), 0, now())
	local elapsed = math.clamp(now() - last, 0, Config.OfflineGrowthCap)
	local cps = totalCps(data)
	local mult = MoneyService.BaseMultiplier(data)
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
	return stripRuntime(profile)
end

-- Generasi fencing sesi ini (diagnostik / uji Studio). Nil = belum akuisisi.
function SaveSystem.GetFencing(player: Player): number?
	return sessionGen[player.UserId]
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
	local myGen = sessionGen[player.UserId]
	if myGen == nil then
		warn("[Save] skip save (tanpa fencing generation): " .. player.Name)
		return false
	end
	-- Fast-fail cepat saja; OTORISASI FINAL ada di transform UpdateAsync di bawah.
	-- Kepemilikan bisa berpindah antara cek ini dan tulis, jadi hasil VerifyLock
	-- tidak pernah dijadikan dasar keputusan tulis durable.
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
	-- Batas payload DataStore 4MB: tolak sebelum UpdateAsync agar tidak
	-- membakar budget throttle/retry untuk tulis yang pasti gagal.
	local payloadOk, payloadJson = pcall(function()
		return HttpService:JSONEncode(snap)
	end)
	if not payloadOk or #payloadJson > 4 * 1024 * 1024 then
		warn("[Save] skip save (payload terlalu besar): " .. player.Name)
		return false
	end
	local mySession = { job = game.JobId, token = sessionToken[player.UserId] }
	local baseAt = d._baseAt or 0
	local baseSession = SaveSystem.NormalizeSession(d._baseSession)
	local key = PROFILE_KEY_PREFIX .. player.UserId
	for attempt = 1, 3 do
		local ok, res = pcall(function()
			return store:UpdateAsync(key, function(old)
				-- Penolakan ATOMIK berdasarkan nilai cloud TERKINI (bukan hasil
				-- VerifyLock yang bisa basi): (a) generation basi, (b) identitas
				-- sesi basi (job+token LENGKAP, bukan JobId saja), (c) cloud lebih
				-- baru dari basis sesi asing. Tulis sesama sesi sendiri selalu
				-- diizinkan (autosave + leave-save konkuren aman).
				if old == nil then
					return nil -- ABORT: profil lenyap setelah fence, fail-closed
				end
				if type(old) ~= "table" or type(old.data) ~= "table" then
					return nil -- ABORT: legacy mentah/korup tidak ditimpa via save
				end
				local oldGen = if type(old.gen) == "number" then old.gen else 0
				local oldS = SaveSystem.NormalizeSession(old.session)
				local sameAsMe = oldS.job == mySession.job and oldS.token == mySession.token
				local sameAsBase = baseSession.token ~= nil
					and oldS.job == baseSession.job
					and oldS.token == baseSession.token
				if oldGen ~= myGen then
					return old -- (a) fencing: generasi kita basi -> TOLAK
				end
				if not sameAsMe then
					return old -- (b) sesi pemegang gen ini bukan kita -> TOLAK
				end
				if (old.at or 0) > baseAt and not sameAsBase then
					return old -- (c) cloud lebih baru dari sesi asing -> TOLAK
				end
				old.data = snap
				old.at = now()
				old.v = SCHEMA_VERSION
				return old
			end)
		end)
		if ok then
			if type(res) ~= "table" or type(res.data) ~= "table" then
				warn("[Save] tulis dibatalkan (keadaan tak terduga), skip save: " .. player.Name)
				return false
			end
			local rs = SaveSystem.NormalizeSession(res.session)
			local resGen = if type(res.gen) == "number" then res.gen else -1
			if resGen == myGen and rs.job == mySession.job and rs.token == mySession.token then
				d._baseAt = res.at
				d._baseSession = res.session
				d._baseGen = resGen
				baseAt = res.at
				baseSession = rs
				return true
			end
			warn("[Save] konflik versi, skip save: " .. player.Name)
			return false
		end
		if attempt < 3 then
			backoff(attempt)
		end
	end
	warn("[Save] save gagal 3x: " .. player.Name)
	return false
end

-- autosave stagger: jeda antar pemain agar tidak spike; lewati yang sudah leave-save
task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		for _, p in Players:GetPlayers() do
			if not savedOnLeave[p.UserId] then
				SaveSystem.Save(p)
			end
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
	-- kuras antrean analitik sebelum proses mati (tutup window 60 dtk)
	pcall(Analytics.Flush)
end)

return SaveSystem

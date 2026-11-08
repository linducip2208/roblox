-- TreasureService.luau -- SERVER ONLY. Lokasi & jawaban tidak pernah ke client.
-- Multi-spot: tiap riddle punya spot sendiri, tidak saling menimpa.
-- Spot dipersist di profile.treasure.spots agar selamat dari disconnect.
local Players = game:GetService("Players")
local TConfig = require(game.ReplicatedStorage.Shared.TreasureConfig)
local Answers = require(script.Parent.TreasureAnswers)
local EventManager = require(script.Parent.EventManager)

local TreasureService = {}
-- [userId] = { [riddleId] = { pos: Vector3, spawnedAt: number } }
local spots: { [number]: { [string]: any } } = {}
local lastAttempt: { [number]: number } = {}
local lastDig: { [number]: number } = {}
local lastPing: { [number]: number } = {}

local function now(): number
	return os.clock()
end

local function ensureUser(uid: number)
	if not spots[uid] then
		spots[uid] = {}
	end
	return spots[uid]
end

-- Hidupkan kembali spot dari save (posisi sama, tidak random ulang).
function TreasureService.RestoreSpots(uid: number, saved: any?)
	local u = ensureUser(uid)
	if type(saved) ~= "table" then
		return
	end
	for riddleId, p in saved do
		if type(p) == "table" and type(p.x) == "number" then
			u[riddleId] = { pos = Vector3.new(p.x, p.y, p.z), spawnedAt = os.time() }
		end
	end
end

local function persistSpot(profile, riddleId: string, pos: Vector3)
	profile.treasure.spots = profile.treasure.spots or {}
	profile.treasure.spots[riddleId] = { x = pos.X, y = pos.Y, z = pos.Z }
end

local function clearSpot(profile, uid: number, riddleId: string)
	if spots[uid] then
		spots[uid][riddleId] = nil
	end
	if profile.treasure.spots then
		profile.treasure.spots[riddleId] = nil
	end
end

function TreasureService.GetNextUnsolved(profile)
	local t = profile.treasure
	for _, r in TConfig.Riddles do
		if not t.solved[r.Id] then
			return r
		end
	end
	return nil
end

-- Riddle untuk client: TANPA jawaban. Client tidak boleh tahu index benar.
function TreasureService.PublicRiddle(profile)
	local r = TreasureService.GetNextUnsolved(profile)
	if not r then
		return nil
	end
	return { Id = r.Id, Q = r.Q, Choices = r.Choices,
		HintsUsed = profile.treasure.hintsUsed[r.Id] or 0,
		Solved = false, Zone = nil }
end

function TreasureService.SubmitAnswer(uid: number, profile, riddleId: string, choiceIdx: number): (boolean, any)
	local t = profile.treasure
	if (t.lockedUntil[riddleId] or 0) > os.time() then
		return false, "locked_coba_lagi_nanti"
	end
	if now() - (lastAttempt[uid] or -99) < TConfig.Answer.CooldownSecs then
		return false, "terlalu_cepat"
	end
	lastAttempt[uid] = now()
	local correct = Answers[riddleId]
	if not correct then
		return false, "riddle_invalid"
	end
	if t.solved[riddleId] then
		return false, "sudah_selesai"
	end
	local nextR = TreasureService.GetNextUnsolved(profile)
	if not nextR or nextR.Id ~= riddleId then
		return false, "bukan_urutan"
	end
	-- cari def untuk reward/zone (tanpa jawaban)
	local def = nil
	for _, r in TConfig.Riddles do
		if r.Id == riddleId then
			def = r
			break
		end
	end
	if not def then
		return false, "riddle_invalid"
	end
	if choiceIdx == correct then
		t.solved[riddleId] = true
		t.fails[riddleId] = 0
		t.activeRiddle = riddleId
		-- spawn spot sendiri untuk riddle ini (tidak menimpa riddle lain)
		local base = TConfig.SpawnPoints[math.random(#TConfig.SpawnPoints)]
		local o = TConfig.RandomOffset
		local pos = base + Vector3.new(math.random(-o, o), 0, math.random(-o, o))
		ensureUser(uid)[riddleId] = { pos = pos, spawnedAt = os.time() }
		persistSpot(profile, riddleId, pos)
		return true, { Zone = def.Zone, RewardCash = def.RewardCash, RewardKey = def.RewardKey }
	else
		t.fails[riddleId] = (t.fails[riddleId] or 0) + 1
		if t.fails[riddleId] >= TConfig.Answer.MaxFails then
			t.lockedUntil[riddleId] = os.time() + TConfig.Answer.LockoutSecs
			return false, "gagal_5x_tunggu_60d"
		end
		return false, "jawaban_salah"
	end
end

function TreasureService.RequestHint(profile, riddleId: string, playerCash: number): (boolean, string, number)
	local t = profile.treasure
	local def = nil
	for _, r in TConfig.Riddles do
		if r.Id == riddleId then
			def = r
			break
		end
	end
	if not def then
		return false, "riddle_invalid", 0
	end
	if t.solved[riddleId] then
		return false, "sudah_selesai", 0
	end
	local used = t.hintsUsed[riddleId] or 0
	if used >= TConfig.Hint.MaxHintsPerRiddle then
		return false, "hint_habis", 0
	end
	if EventManager.HintFree() then -- Treasure Rush: hint gratis
		t.hintsUsed[riddleId] = used + 1
		t.lastHintAt = os.time()
		return true, (used == 0 and def.Hint1 or def.Hint2), 0
	end
	local sinceHint = os.time() - (t.lastHintAt or 0)
	if sinceHint >= TConfig.Hint.CooldownSecs then
		t.hintsUsed[riddleId] = used + 1
		t.lastHintAt = os.time()
		return true, (used == 0 and def.Hint1 or def.Hint2), 0
	else
		if playerCash < TConfig.Hint.CostCoins then
			return false, ("tunggu_%ds_atau_bayar_%d"):format(TConfig.Hint.CooldownSecs - sinceHint, TConfig.Hint.CostCoins), 0
		end
		t.hintsUsed[riddleId] = used + 1
		t.lastHintAt = os.time()
		return true, (used == 0 and def.Hint1 or def.Hint2), TConfig.Hint.CostCoins
	end
end

-- Kembalikan spot aktif yg belum digali (terdekat dari pemain).
local function nearestSpot(uid: number, profile, hrpPos: Vector3): (string?, any?)
	local u = spots[uid]
	if not u then
		return nil, nil
	end
	local bestId, best, bestD = nil, nil, math.huge
	for riddleId, s in u do
		if not profile.treasure.found[riddleId] then
			local d = (hrpPos - s.pos).Magnitude
			if d < bestD then
				bestId, best, bestD = riddleId, s, d
			end
		end
	end
	return bestId, best
end

-- Kompas: hanya jarak kasar + arah mata angin, TIDAK pernah koordinat.
function TreasureService.CompassPing(uid: number, player: Player, profile): (boolean, string)
	if not profile.treasure.hasCompass then
		return false, "butuh_kompas"
	end
	if now() - (lastPing[uid] or -99) < 2 then
		return false, "ping_cooldown"
	end
	lastPing[uid] = now()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false, "nochar"
	end
	local riddleId, s = nearestSpot(uid, profile, hrp.Position)
	if not s then
		if TreasureService.GetNextUnsolved(profile) then
			return false, "selesaikan_teka_teki_dulu"
		end
		return false, "semua_harta_sudah_digali"
	end
	local delta = s.pos - hrp.Position
	local dist = math.floor(delta.Magnitude / 10) * 10
	local dir = "?"
	if math.abs(delta.X) > math.abs(delta.Z) then
		dir = delta.X > 0 and "Timur" or "Barat"
	else
		dir = delta.Z > 0 and "Selatan" or "Utara"
	end
	local beepMs = math.clamp(math.floor(delta.Magnitude * 8), 120, 1000)
	return true, ("%s %dm ke %s"):format(riddleId, dist, dir) .. "|" .. tostring(beepMs)
end

function TreasureService.TryDig(uid: number, player: Player, profile): (boolean, any)
	local t = profile.treasure
	if TConfig.Dig.NeedShovel and not t.hasShovel then
		return false, "butuh_sekop_beli_dulu"
	end
	if now() - (lastDig[uid] or -99) < TConfig.Dig.CooldownSecs then
		return false, "gali_cooldown"
	end
	lastDig[uid] = now()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false, "nochar"
	end
	-- cocokkan dengan spot aktif mana pun dalam radius (anti gali sembarang)
	local u = spots[uid]
	if not u then
		return false, "belum_ada_harta"
	end
	local hitId: string? = nil
	for riddleId, s in u do
		if not t.found[riddleId] and (hrp.Position - s.pos).Magnitude <= TConfig.Dig.Radius then
			hitId = riddleId
			break
		end
	end
	if not hitId then
		return false, "belum_tepat_ikuti_kompas"
	end
	if t.keys < 1 then
		return false, "butuh_kunci_selesaikan_teka_teki"
	end
	t.keys -= 1
	t.found[hitId] = true
	t.level += 1
	clearSpot(profile, uid, hitId)
	local def = nil
	for _, r in TConfig.Riddles do
		if r.Id == hitId then
			def = r
			break
		end
	end
	local bonus = def and def.RewardCash or 5000
	return true, { riddleId = hitId, bonus = bonus, level = t.level }
end

function TreasureService.BindUid(uid: number, profile)
	TreasureService.RestoreSpots(uid, profile.treasure.spots)
end

Players.PlayerRemoving:Connect(function(p)
	spots[p.UserId] = nil
	lastAttempt[p.UserId] = nil
	lastDig[p.UserId] = nil
	lastPing[p.UserId] = nil
end)

return TreasureService

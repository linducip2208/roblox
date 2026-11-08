-- TreasureService.luau — SERVER ONLY. Lokasi & jawaban tidak pernah ke client.
local Players = game:GetService("Players")
local TConfig = require(game.ReplicatedStorage.Shared.TreasureConfig)

local TreasureService = {}
-- [userId] = { riddleId, pos: Vector3, spawnedAt }
local spots: { [number]: any } = {}
local lastAttempt: { [number]: number } = {}
local lastDig: { [number]: number } = {}
local lastPing: { [number]: number } = {}

local function now(): number return os.clock() end

function TreasureService.GetNextUnsolved(profile)
	local t = profile.treasure
	for _, r in TConfig.Riddles do
		if not t.solved[r.Id] then return r end
	end
	return nil
end

-- Riddle untuk client: TANPA Answer. Client tidak boleh tahu index benar.
function TreasureService.PublicRiddle(profile)
	local r = TreasureService.GetNextUnsolved(profile)
	if not r then return nil end
	return { Id = r.Id, Q = r.Q, Choices = r.Choices,
		HintsUsed = profile.treasure.hintsUsed[r.Id] or 0,
		Solved = false, Zone = nil }
end

function TreasureService.SubmitAnswer(profile, riddleId: string, choiceIdx: number): (boolean, string | table)
	local t = profile.treasure
	-- lockout?
	if (t.lockedUntil[riddleId] or 0) > os.time() then
		return false, "locked_coba_lagi_nanti"
	end
	local key = (profile :: any)._uid or 0
	if now() - (lastAttempt[key] or -99) < TConfig.Answer.CooldownSecs then
		return false, "terlalu_cepat"
	end
	lastAttempt[key] = now()
	-- cari riddle (server side punya Answer)
	local def = nil
	for _, r in TConfig.Riddles do
		if r.Id == riddleId then def = r break end
	end
	if not def then return false, "riddle_invalid" end
	if t.solved[riddleId] then return false, "sudah_selesai" end
	-- hanya riddle aktif yg boleh dijawab (urutan)
	local nextR = TreasureService.GetNextUnsolved(profile)
	if not nextR or nextR.Id ~= riddleId then return false, "bukan_urutan" end
	if type(choiceIdx) ~= "number" then return false, "input_invalid" end
	if choiceIdx == def.Answer then
		t.solved[riddleId] = true
		t.fails[riddleId] = 0
		t.activeRiddle = riddleId
		-- spawn titik server-side
		local base = TConfig.SpawnPoints[math.random(#TConfig.SpawnPoints)]
		local o = TConfig.RandomOffset
		local pos = base + Vector3.new(math.random(-o, o), 0, math.random(-o, o))
		spots[key] = { riddleId = riddleId, pos = pos, spawnedAt = os.time() }
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
	-- return ok, hintText, costCharged. Cost dipotong oleh Main via MoneyService.
	local t = profile.treasure
	local def = nil
	for _, r in TConfig.Riddles do
		if r.Id == riddleId then def = r break end
	end
	if not def then return false, "riddle_invalid", 0 end
	local used = t.hintsUsed[riddleId] or 0
	if used >= TConfig.Hint.MaxHintsPerRiddle then return false, "hint_habis", 0 end
	local sinceHint = os.time() - (t.lastHintAt or 0)
	if sinceHint >= TConfig.Hint.CooldownSecs then
		-- gratis karena cooldown lewat
		t.hintsUsed[riddleId] = used + 1
		t.lastHintAt = os.time()
		return true, (used == 0 and def.Hint1 or def.Hint2), 0
	else
		-- bayar koin untuk skip tunggu
		if playerCash < TConfig.Hint.CostCoins then
			return false, ("tunggu_%ds_atau_bayar_%d"):format(TConfig.Hint.CooldownSecs - sinceHint, TConfig.Hint.CostCoins), 0
		end
		t.hintsUsed[riddleId] = used + 1
		t.lastHintAt = os.time()
		return true, (used == 0 and def.Hint1 or def.Hint2), TConfig.Hint.CostCoins
	end
end

-- Kompas: hanya jarak kasar + arah mata angin, TIDAK pernah koordinat.
function TreasureService.CompassPing(player: Player, profile): (boolean, string)
	if not profile.treasure.hasCompass then return false, "butuh_kompas" end
	local key = (profile :: any)._uid or 0
	if now() - (lastPing[key] or -99) < 2 then return false, "ping_cooldown" end
	lastPing[key] = now()
	local spot = spots[key]
	if not spot then return false, "selesaikan_teka_teki_dulu" end
	if profile.treasure.found[spot.riddleId] then return false, "sudah_digali" end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false, "nochar" end
	local delta = spot.pos - hrp.Position
	local dist = math.floor(delta.Magnitude / 10) * 10 -- kasarkan ke 10 stud
	local dir = "?"
	if math.abs(delta.X) > math.abs(delta.Z) then
		dir = delta.X > 0 and "Timur" or "Barat"
	else
		dir = delta.Z > 0 and "Selatan" or "Utara"
	end
	-- bunyi lebih cepat saat dekat: kirim interval beep, client yg bunyikan
	local beepMs = math.clamp(math.floor(delta.Magnitude * 8), 120, 1000)
	return true, ("%dm ke %s"):format(dist, dir) .. "|" .. tostring(beepMs)
end

function TreasureService.TryDig(player: Player, profile): (boolean, string | table)
	local t = profile.treasure
	if TConfig.Dig.NeedShovel and not t.hasShovel then
		return false, "butuh_sekop_beli_dulu"
	end
	local key = (profile :: any)._uid or 0
	if now() - (lastDig[key] or -99) < TConfig.Dig.CooldownSecs then
		return false, "gali_cooldown"
	end
	lastDig[key] = now()
	local spot = spots[key]
	if not spot then return false, "belum_ada_harta" end
	if t.found[spot.riddleId] then return false, "sudah_digali" end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false, "nochar" end
	if (hrp.Position - spot.pos).Magnitude > TConfig.Dig.Radius then
		return false, "belum_tepat_ikuti_kompas"
	end
	-- butuh 1 kunci untuk buka peti
	if t.keys < 1 then return false, "butuh_kunci_selesaikan_teka_teki" end
	t.keys -= 1
	t.found[spot.riddleId] = true
	t.level += 1
	spots[key] = nil
	-- reward digali: 2x reward riddle (digabung dengan reward solve di Main)
	local def = nil
	for _, r in TConfig.Riddles do
		if r.Id == spot.riddleId then def = r break end
	end
	local bonus = def and def.RewardCash or 5000
	return true, { riddleId = spot.riddleId, bonus = bonus, level = t.level }
end

-- Setter uid internal (dipanggil Main saat join agar rate-limit per player)
function TreasureService.BindUid(profile, userId: number)
	(profile :: any)._uid = userId;
	(profile :: any)._lastPing = 0
end

Players.PlayerRemoving:Connect(function(p)
	spots[p.UserId] = nil
	lastAttempt[p.UserId] = nil
	lastDig[p.UserId] = nil
	lastPing[p.UserId] = nil
end)

return TreasureService

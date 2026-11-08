-- DailyReward.luau — login harian 7 hari, claim via RemoteFunction
local DailyReward = {}
local REWARDS = { 500, 1500, 4000, 10000, 25000, 60000, 150000 }

-- Kunci hari = tahun+hari-ke (%Y%j) agar aman saat tahun baru.
local function dayKey(): string
	return os.date("%Y%j")
end

local function prevDayKey(): string
	return os.date("%Y%j", os.time() - 86400)
end

function DailyReward.CanClaim(profile): boolean
	return profile.lastDailyYday ~= dayKey()
end

function DailyReward.Claim(profile): (boolean, number)
	if not DailyReward.CanClaim(profile) then
		return false, 0
	end
	local streak = (profile.dailyStreak or 0) + 1
	if streak > 7 then
		streak = 1
	end
	-- reset jika hari terakhir bukan kemarin (skip sehari)
	if profile.lastDailyYday ~= "" and profile.lastDailyYday ~= prevDayKey() then
		streak = 1
	end
	profile.dailyStreak = streak
	profile.lastDailyYday = dayKey()
	return true, REWARDS[streak]
end

function DailyReward.Rewards()
	return REWARDS
end

return DailyReward

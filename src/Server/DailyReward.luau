-- DailyReward.luau — login harian 7 hari, claim via RemoteFunction
local DailyReward = {}
local REWARDS = { 500, 1500, 4000, 10000, 25000, 60000, 150000 }

function DailyReward.CanClaim(profile): boolean
	local today = os.date("!*t").yday
	return profile.lastDailyYday ~= today
end

function DailyReward.Claim(profile): (boolean, number)
	if not DailyReward.CanClaim(profile) then return false, 0 end
	local today = os.date("!*t").yday
	local streak = (profile.dailyStreak or 0) + 1
	if streak > 7 then streak = 1 end
	-- reset jika skip sehari (sederhana: jika yday loncat >1, reset)
	if profile.lastDailyYday and (today - profile.lastDailyYday > 1) and not (today == 1) then
		streak = 1
	end
	profile.dailyStreak = streak
	profile.lastDailyYday = today
	return true, REWARDS[streak]
end

function DailyReward.Rewards()
	return REWARDS
end

return DailyReward

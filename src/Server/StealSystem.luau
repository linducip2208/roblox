-- StealSystem.luau — server-authoritative, anti teleport/speed
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.Shared.Config)

local StealSystem = {}
local locks: { [number]: number } = {} -- victimId -> unlock time
local cooldowns: { [number]: number } = {} -- thiefId -> next allowed time
local channels: { [number]: any } = {} -- thiefId -> { victimId, uid, startTime }

local function charPos(player: Player)
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or nil
end

local function inSafeZone(player: Player): boolean
	local c = player.Character
	if not c then
		return true
	end
	local hrp = c:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return true
	end
	-- jika ada part SafeZone di workspace, cek jarak sederhana
	local zone = workspace:FindFirstChild(Config.SafeZoneName, true)
	if zone and zone:IsA("BasePart") then
		return (hrp.Position - zone.Position).Magnitude < (zone.Size.Magnitude / 2)
	end
	return false
end

function StealSystem.LockBase(player: Player, rebirths: number, isVip: boolean)
	local t = Config.BaseLockTime + rebirths * Config.LockPerRebirth
	if isVip then
		t += Config.VipExtraLock
	end
	locks[player.UserId] = os.time() + t
end

function StealSystem.IsLocked(victim: Player): boolean
	local u = locks[victim.UserId]
	return u ~= nil and os.time() < u
end

function StealSystem.CanSteal(thief: Player, victim: Player): (boolean, string)
	if thief == victim then
		return false, "self"
	end
	if StealSystem.IsLocked(victim) then
		return false, "locked"
	end
	if inSafeZone(thief) or inSafeZone(victim) then
		return false, "safezone"
	end
	local now = os.clock()
	if cooldowns[thief.UserId] and now < cooldowns[thief.UserId] then
		return false, "cooldown"
	end
	local tp, vp = charPos(thief), charPos(victim)
	if not tp or not vp then
		return false, "nochar"
	end
	-- anti teleport: jika thief pindah >200 stud dalam 1 tick, tolak (dicek di Main via lastPos)
	if (tp - vp).Magnitude > Config.StealDistance + 10 then
		return false, "toofar"
	end
	return true
end

-- dipanggil dari Remote RequestSteal. Mulai channel 3 detik.
function StealSystem.RequestSteal(thief: Player, victim: Player, uid: string): (boolean, string)
	local ok, err = StealSystem.CanSteal(thief, victim)
	if not ok then
		return false, err
	end
	channels[thief.UserId] = { victimId = victim.UserId, uid = uid, startTime = os.clock(), startPos = charPos(thief) }
	return true, "channel_started"
end

-- dipanggil tiap heartbeat untuk selesaikan channel
function StealSystem.PollChannel(thief: Player): any?
	return channels[thief.UserId]
end

function StealSystem.ClearChannel(thief: Player)
	channels[thief.UserId] = nil
end

function StealSystem.SetCooldown(thief: Player)
	cooldowns[thief.UserId] = os.clock() + Config.StealCooldown
end

Players.PlayerRemoving:Connect(function(p)
	locks[p.UserId] = nil
	cooldowns[p.UserId] = nil
	channels[p.UserId] = nil
end)

return StealSystem

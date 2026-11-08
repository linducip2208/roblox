-- EventManager.luau — Hujan Kopi Sabtu 19:00 WIB x2 income 30 mnt
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local EventManager = {}
EventManager.Active = false
EventManager.EndsAt = 0
EventManager.CurrentKey = "hujan"
local gen = 0 -- token agar task lama tidak mematikan event baru

local function activeDef()
	return Config.Events[EventManager.CurrentKey] or Config.Events[Config.DefaultEvent or "hujan"]
end

local function getEventRemote()
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
	end
	local r = f:FindFirstChild("EventState")
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = "EventState"
		r.Parent = f
	end
	return r
end

function EventManager.IsActive(): boolean
	if not EventManager.Active then
		return false
	end
	if os.time() > EventManager.EndsAt then
		EventManager.Active = false
		return false
	end
	return true
end

function EventManager.Start(minutes: number?, eventKey: string?)
	if EventManager.IsActive() then
		return -- event sedang jalan, abaikan start ganda (anti spam admin)
	end
	eventKey = eventKey or Config.DefaultEvent or "hujan"
	local def = Config.Events[eventKey] or Config.Events.hujan
	minutes = minutes or def.DurationMinutes
	gen += 1
	local myGen = gen
	EventManager.CurrentKey = eventKey
	EventManager.Active = true
	EventManager.EndsAt = os.time() + minutes * 60
	getEventRemote():FireAllClients({ active = true, endsAt = EventManager.EndsAt, name = def.Name, mult = def.IncomeMultiplier })
	print(("[Event] %s mulai %d mnt"):format(def.Name, minutes))
	task.delay(minutes * 60, function()
		if myGen ~= gen then return end -- sudah diganti event baru
		EventManager.Active = false
		getEventRemote():FireAllClients({ active = false, name = def.Name })
	end)
end

function EventManager.Multiplier(): number
	if not EventManager.IsActive() then
		return 1
	end
	return activeDef().IncomeMultiplier or 1
end

function EventManager.HintFree(): boolean
	if not EventManager.IsActive() then
		return false
	end
	return activeDef().HintDiscount == true
end

-- auto: cek tiap 60s apakah Sabtu 12:00 UTC (=19 WIB)
task.spawn(function()
	while true do
		task.wait(60)
		if Config.Event.AutoSaturday19WIB then
			local t = os.date("!*t") -- UTC
			if t.wday == 7 and t.hour == 12 and t.min < 5 and not EventManager.IsActive() then
				EventManager.Start()
			end
		end
	end
end)

-- command manual untuk test: ketik di console server `require(...EventManager).Start(1)`
return EventManager

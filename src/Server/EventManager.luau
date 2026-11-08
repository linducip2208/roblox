-- EventManager.luau — Hujan Kopi Sabtu 19:00 WIB x2 income 30 mnt
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local EventManager = {}
EventManager.Active = false
EventManager.EndsAt = 0

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
	if not EventManager.Active then return false end
	if os.time() > EventManager.EndsAt then
		EventManager.Active = false
		return false
	end
	return true
end

function EventManager.Start(minutes: number?)
	minutes = minutes or Config.Event.DurationMinutes
	EventManager.Active = true
	EventManager.EndsAt = os.time() + minutes * 60
	getEventRemote():FireAllClients({ active = true, endsAt = EventManager.EndsAt, name = Config.Event.Name })
	print(("[Event] %s mulai %d mnt"):format(Config.Event.Name, minutes))
	task.delay(minutes * 60, function()
		EventManager.Active = false
		getEventRemote():FireAllClients({ active = false, name = Config.Event.Name })
	end)
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

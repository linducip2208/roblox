-- Analytics.luau -- log ringan ke DataStore + siap webhook
local DataStoreService = game:GetService("DataStoreService")
local Analytics = {}
local store
pcall(function()
	store = DataStoreService:GetDataStore("KebunAnalytics_v1")
end)

local function bump(key: string, delta: number)
	if not store then
		return
	end
	task.spawn(function()
		local day = os.date("!%Y-%m-%d")
		pcall(store.UpdateAsync, store, day .. ":" .. key, function(old)
			return (old or 0) + delta
		end)
	end)
end

function Analytics.Join()
	bump("join", 1)
end

function Analytics.Buy(amount: number)
	bump("buy_count", 1)
	bump("buy_value", amount)
end

function Analytics.Steal()
	bump("steal", 1)
end

function Analytics.Rebirth()
	bump("rebirth", 1)
end

function Analytics.Riddle()
	bump("riddle_solved", 1)
end

function Analytics.Event()
	bump("event", 1)
end

return Analytics

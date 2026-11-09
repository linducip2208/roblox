-- Analytics.luau -- log ringan ke DataStore + siap webhook
local DataStoreService = game:GetService("DataStoreService")
local Analytics = {}
local FLUSH_INTERVAL = 60 -- detik; jendela hilang-maksimal saat crash
local pending: { [string]: number } = {} -- "YYYY-MM-DD:key" -> delta terkumpul
local store
pcall(function()
	store = DataStoreService:GetDataStore("KebunAnalytics_v1")
end)

local function bump(key: string, delta: number)
	if not store then
		return
	end
	-- agregat di memori; flush berkala menggabungkan via UpdateAsync add.
	local day = os.date("!%Y-%m-%d")
	local k = day .. ":" .. key
	pending[k] = (pending[k] or 0) + delta
end

-- Flush tiap 60 detik (1 thread, bukan 1 thread per event). Kunci dihitung saat
-- bump sehingga ganti hari otomatis memakai kunci baru. Gagal flush = antre lagi.
-- Jendela hilang maksimal 60 detik saat crash: dapat diterima untuk analitik
-- (BUKAN data pemain — profil pemain tetap ditulis langsung via SaveSystem).
task.spawn(function()
	while true do
		task.wait(FLUSH_INTERVAL)
		if store then
			local batch = {}
			for k, v in pending do
				batch[k] = v
				pending[k] = nil
			end
			for k, v in batch do
				if v ~= 0 then
					local ok = pcall(store.UpdateAsync, store, k, function(old)
						return (old or 0) + v
					end)
					if not ok then
						pending[k] = (pending[k] or 0) + v
					end
				end
			end
		end
	end
end)

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

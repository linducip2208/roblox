-- Main.server.luau — wiring Remotes + income + steal channel + shop + rebirth
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local SaveSystem = require(script.Parent.SaveSystem)
local MoneyService = require(script.Parent.MoneyService)
local PlotManager = require(script.Parent.PlotManager)
local StealSystem = require(script.Parent.StealSystem)
local MapBuilder = require(script.Parent.MapBuilder)
local Leaderboard = require(script.Parent.Leaderboard)
local GamepassHandler = require(script.Parent.GamepassHandler)
local EventManager = require(script.Parent.EventManager)
local PlotVisuals = require(script.Parent.PlotVisuals)
local ShopRotation = require(ReplicatedStorage.Shared.ShopRotation)

MapBuilder.Build()

-- Buat Remotes sekali
local function getOrCreate(name, class)
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
	end
	local r = f:FindFirstChild(name)
	if not r then
		r = Instance.new(class)
		r.Name = name
		r.Parent = f
	end
	return r
end

local RequestBuy = getOrCreate("RequestBuy", "RemoteFunction")
local RequestSteal = getOrCreate("RequestSteal", "RemoteFunction")
local RequestLock = getOrCreate("RequestLock", "RemoteEvent")
local RequestRebirth = getOrCreate("RequestRebirth", "RemoteFunction")
local RequestDaily = getOrCreate("RequestDaily", "RemoteFunction")
local RequestRedeem = getOrCreate("RequestRedeem", "RemoteFunction")
local UpdateHud = getOrCreate("UpdateHud", "RemoteEvent")
local EventState = getOrCreate("EventState", "RemoteEvent")
local DailyReward = require(script.Parent.DailyReward)
local RedeemCode = require(script.Parent.RedeemCode)
local Analytics = require(script.Parent.Analytics)
local TreasureService = require(script.Parent.TreasureService)
local InventoryService = require(script.Parent.InventoryService)
local TreasureConfig = require(ReplicatedStorage.Shared.TreasureConfig)

function RequestRedeem.OnServerInvoke(player: Player, code: string)
	if type(code) ~= "string" or #code > 32 then
		return false, "kode_salah"
	end
	local profile = SaveSystem.Get(player)
	if not profile then return false, "noload" end
	local ok, res = RedeemCode.Redeem(profile, code or "")
	if not ok then return false, res end
	MoneyService.Add(player, res :: number, "redeem:" .. tostring(code))
	SaveSystem.Save(player)
	return true, res
end

function RequestDaily.OnServerInvoke(player: Player)
	local profile = SaveSystem.Get(player)
	if not profile then return false, "noload" end
	local ok, amount = DailyReward.Claim(profile)
	if not ok then return false, "sudah_claim" end
	MoneyService.Add(player, amount, "daily")
	SaveSystem.Save(player)
	return true, amount
end

local lastPos: { [number]: Vector3 } = {}

local function isVip(player: Player): boolean
	if Config.Gamepasses.VIP == 0 then return false end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, Config.Gamepasses.VIP)
	return ok and owns
end

-- SHOP: beli bibit (cek stok restock 5 mnt)
function RequestBuy.OnServerInvoke(player: Player, itemId: string)
	if type(itemId) ~= "string" or #itemId > 64 then
		return false, "invalid"
	end
	local profile = SaveSystem.Get(player)
	if not profile then return false, "noload" end
	local def = Items.ById[itemId]
	if not def then return false, "invalid" end
	if def.Rarity == "Secret" then return false, "secret_only_steal" end
	if (def :: any).EventOnly and not EventManager.IsActive() then
		return false, "event_only"
	end
	if not ShopRotation.IsInStock(itemId) and not (def :: any).EventOnly then
		return false, "out_of_stock"
	end
	if MoneyService.Get(player) < def.Cost then return false, "miskin" end
	local ok, slotOrErr = PlotManager.Plant(profile, itemId)
	if not ok then return false, slotOrErr end
	if not (def :: any).EventOnly then
		ShopRotation.Take(itemId)
	end
	-- Luck boost: percepat growth 25% visual saja (plantedAt dimajukan)
	if GamepassHandler.HasLuck(player) then
		local slot = profile.slots[slotOrErr]
		if slot then slot.plantedAt -= math.floor(def.GrowthTime * 0.25) end
	end
	MoneyService.Spend(player, def.Cost)
	Analytics.Buy(def.Cost)
	return true, slotOrErr
end

-- LOCK base manual (tombol kunci)
RequestLock.OnServerEvent:Connect(function(player: Player)
	local profile = SaveSystem.Get(player)
	if profile then
		StealSystem.LockBase(player, profile.rebirths or 0, isVip(player))
	end
end)

-- REBIRTH: reset items + cash, naik multiplier (syarat skala linear)
function RequestRebirth.OnServerInvoke(player: Player)
	local profile = SaveSystem.Get(player)
	if not profile then return false, "noload" end
	local need = Config.RebirthRequirementFor(profile.rebirths or 0)
	if MoneyService.Get(player) < need then
		return false, "belum_cukup_" .. tostring(need)
	end
	profile.slots = {}
	profile.rebirths += 1
	Analytics.Rebirth()
	MoneyService.Set(player, Config.StartingCash)
	profile.cash = Config.StartingCash
	MoneyService.RefreshMultiplier(player, profile)
	StealSystem.LockBase(player, profile.rebirths, isVip(player))
	return true, { rebirths = profile.rebirths, nextNeed = Config.RebirthRequirementFor(profile.rebirths) }
end

-- STEAL: auto-pilih item termahal yang grown (client cukup kirim victimUserId)
function RequestSteal.OnServerInvoke(thief: Player, victimUserId: number, uid: string?)
	if type(victimUserId) ~= "number" then return false, "victim_off" end
	if uid ~= nil and (type(uid) ~= "string" or #uid > 64) then
		return false, "invalid"
	end
	local victim = Players:GetPlayerByUserId(victimUserId)
	if not victim then return false, "victim_off" end
	local vProfile = SaveSystem.Get(victim)
	if not vProfile then return false, "victim_noload" end
	local tProfile = SaveSystem.Get(thief)
	if not tProfile then return false, "noload" end
	if not PlotManager.FindFreeSlot(tProfile) then return false, "thief_penuh" end
	-- jika uid tidak dikirim / tidak valid, pilih otomatis termahal
	local targetUid = uid
	if targetUid == nil or targetUid == "" then
		local best, bestCps = nil, -1
		for _, slot in vProfile.slots do
			if PlotManager.IsGrown(slot) then
				local def = Items.ById[slot.itemId]
				if def and def.CashPerSec > bestCps then
					best, bestCps = slot.uid, def.CashPerSec
				end
			end
		end
		if not best then return false, "nothing_grown" end
		targetUid = best
	else
		-- validasi uid manual: harus milik victim dan sudah grown
		local found, grown = false, false
		for _, slot in vProfile.slots do
			if slot.uid == targetUid then
				found = true
				grown = PlotManager.IsGrown(slot)
				break
			end
		end
		if not found then return false, "invalid" end
		if not grown then return false, "belum_grown" end
	end
	local ok, msg = StealSystem.RequestSteal(thief, victim, targetUid)
	return ok, msg
end

-- INCOME + STEAL CHANNEL loop
task.spawn(function()
	while true do
		task.wait(Config.IncomeTick)
		for _, p in Players:GetPlayers() do
			local profile = SaveSystem.Get(p)
			if profile then
				-- anti-teleport sederhana: tandai posisi
				local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local prev = lastPos[p.UserId]
					if prev and (hrp.Position - prev).Magnitude > 150 then
						-- teleport mencurigakan, batalkan channel
						StealSystem.ClearChannel(p)
					end
					lastPos[p.UserId] = hrp.Position
				end

				-- income (multiplier mengikuti event aktif)
				local raw = PlotManager.TickIncome(profile)
				local mult = 1
				local okM, m = pcall(function() return EventManager.Multiplier() end)
				if okM and type(m) == "number" then mult = m end
				if mult > 1 then
					raw = math.floor(raw * mult)
				end
				if raw > 0 then
					MoneyService.Add(p, raw, "income")
				end
				profile.cash = MoneyService.Get(p)

				-- steal channel progress
				local ch = StealSystem.PollChannel(p)
				if ch then
					local victim = Players:GetPlayerByUserId(ch.victimId)
					if victim then
						local ok, reason = StealSystem.CanSteal(p, victim)
						if not ok and reason ~= "cooldown" then
							-- gagal kecuali cooldown (cooldown dicek di akhir)
							if reason == "locked" or reason == "toofar" or reason == "safezone" then
								StealSystem.ClearChannel(p)
								UpdateHud:FireClient(p, { type = "steal_fail", reason = reason })
							end
						elseif (os.clock() - ch.startTime) >= Config.StealChannelTime then
							-- sukses: pindahkan item (atomik: cek slot dulu, kembalikan slot ASLI jika gagal)
							local vProfile = SaveSystem.Get(victim)
							if vProfile then
								if not PlotManager.FindFreeSlot(profile) then
									StealSystem.ClearChannel(p)
									UpdateHud:FireClient(p, { type = "steal_fail", reason = "thief_penuh" })
								else
									local slotKey: string? = nil
									for k, slot in vProfile.slots do
										if slot.uid == ch.uid then slotKey = k break end
									end
									local stolen = slotKey and vProfile.slots[slotKey] or nil
									if stolen and PlotManager.IsGrown(stolen) then
										vProfile.slots[slotKey] = nil
										local ok2, _ = PlotManager.AddStolenSlot(profile, stolen)
										if ok2 then
											StealSystem.SetCooldown(p)
											StealSystem.ClearChannel(p)
											Analytics.Steal()
											SaveSystem.Save(p)
											SaveSystem.Save(victim)
											UpdateHud:FireClient(p, { type = "steal_ok", itemId = stolen.itemId })
											UpdateHud:FireClient(victim, { type = "stolen", itemId = stolen.itemId, by = p.Name })
										else
											-- kembalikan slot ASLI (uid + plantedAt + mutasi utuh)
											vProfile.slots[slotKey] = stolen
											StealSystem.ClearChannel(p)
										end
									else
										StealSystem.ClearChannel(p)
									end
								end
							end
						end
					else
						StealSystem.ClearChannel(p)
					end
				end

				-- push HUD
				UpdateHud:FireClient(p, {
					type = "tick",
					cash = MoneyService.Get(p),
					mult = MoneyService.GetMultiplier(p),
					locked = StealSystem.IsLocked(p),
				})
			end
		end
	end
end)

-- VISUAL refresh tiap 5 detik: hanya plot milik pemain (Owner == UserId)
task.spawn(function()
	local ItemsMod = Items
	while true do
		task.wait(5)
		local plots = workspace:FindFirstChild("Plots")
		if plots then
			for _, p in Players:GetPlayers() do
				local profile = SaveSystem.Get(p)
				if profile then
					for _, plot in plots:GetChildren() do
						if plot:IsA("BasePart") and plot.Name:match("^Plot_") then
							local o = plot:FindFirstChild("Owner")
							if o and o.Value == tostring(p.UserId) then
								local ok, err = pcall(function()
									PlotVisuals.Refresh(plot, profile.slots, ItemsMod, PlotManager)
								end)
								if not ok then warn(err) end
								break
							end
						end
					end
				end
			end
		end
	end
end)

-- ADMIN chat: ;event [nama] [menit] — nama: hujan/golden/rush/meteor (hanya AdminUserIds)
Players.PlayerAdded:Connect(function(p)
	p.Chatted:Connect(function(msg)
		if msg:sub(1, 6) == ";event" then
			if not Config.AdminUserIds[p.UserId] and game.CreatorId ~= p.UserId then
				return -- bukan admin, abaikan diam-diam (anti abuse)
			end
			local key, mins = msg:match(";event%s+(%a+)%s*(%d*)")
			if not key or Config.Events[key] == nil then key = Config.DefaultEvent or "hujan" end
			mins = tonumber(mins) or nil
			EventManager.Start(mins, key)
		end
	end)
end)
-- ===== HARTA KARUN (server-authoritative, anti-exploit) =====
local RequestRiddle = getOrCreate("RequestRiddle", "RemoteFunction")
local SubmitAnswer = getOrCreate("SubmitAnswer", "RemoteFunction")
local RequestHint = getOrCreate("RequestHint", "RemoteFunction")
local CompassPing = getOrCreate("CompassPing", "RemoteFunction")
local RequestDig = getOrCreate("RequestDig", "RemoteFunction")
local BuyTool = getOrCreate("BuyTool", "RemoteFunction")
local RequestStock = getOrCreate("RequestStock", "RemoteFunction")
local RequestInventory = getOrCreate("RequestInventory", "RemoteFunction")

function RequestInventory.OnServerInvoke(player: Player)
	local profile = SaveSystem.Get(player)
	if not profile then return nil end
	local t = profile.treasure or {}
	local solved, found = 0, 0
	for _, v in t.solved or {} do if v then solved += 1 end end
	for _, v in t.found or {} do if v then found += 1 end end
	return {
		cash = MoneyService.Get(player),
		rebirths = profile.rebirths or 0,
		level = t.level or 1,
		keys = t.keys or 0,
		hasShovel = t.hasShovel == true,
		hasCompass = t.hasCompass == true,
		riddlesSolved = solved,
		treasuresFound = found,
		luck = GamepassHandler.HasLuck(player),
		gpDouble = Config.Gamepasses.DoubleMoney,
		gpVip = Config.Gamepasses.VIP,
		pLuck = Config.Products.LuckBoost15m,
		pUnlock = Config.Products.UnlockInstant,
	}
end

function RequestStock.OnServerInvoke(player: Player)
	return { stock = ShopRotation.Stock, secs = ShopRotation.TimeLeft() }
end

function RequestRiddle.OnServerInvoke(player: Player)
	local profile = SaveSystem.Get(player)
	if not profile then return nil end
	return TreasureService.PublicRiddle(profile)
end

function SubmitAnswer.OnServerInvoke(player: Player, riddleId: string, choiceIdx: number)
	local profile = SaveSystem.Get(player)
	if not profile then return false, "noload" end
	if type(riddleId) ~= "string" or type(choiceIdx) ~= "number" then
		return false, "input_invalid"
	end
	choiceIdx = math.floor(choiceIdx)
	if choiceIdx < 1 or choiceIdx > 4 then return false, "input_invalid" end
	local ok, res = TreasureService.SubmitAnswer(player.UserId, profile, riddleId, choiceIdx)
	if ok then
		-- res = { Zone, RewardCash, RewardKey }: beri reward solve
		MoneyService.Add(player, res.RewardCash, "riddle:" .. riddleId)
		profile.treasure.keys += res.RewardKey
		profile.cash = MoneyService.Get(player)
		SaveSystem.Save(player)
		Analytics.Buy(0) -- catat progres (reuse counter aman)
		return true, res
	end
	SaveSystem.Save(player)
	return false, res
end

function RequestHint.OnServerInvoke(player: Player, riddleId: string)
	local profile = SaveSystem.Get(player)
	if not profile then return false, "noload" end
	if type(riddleId) ~= "string" then return false, "input_invalid" end
	local ok, hint, cost = TreasureService.RequestHint(profile, riddleId, MoneyService.Get(player))
	if not ok then return false, hint end
	if cost > 0 then
		if not MoneyService.Spend(player, cost) then return false, "koin_kurang" end
		profile.cash = MoneyService.Get(player)
	end
	SaveSystem.Save(player)
	return true, hint
end

function CompassPing.OnServerInvoke(player: Player)
	local profile = SaveSystem.Get(player)
	if not profile then return false, "noload" end
	return TreasureService.CompassPing(player.UserId, player, profile)
end

function RequestDig.OnServerInvoke(player: Player)
	local profile = SaveSystem.Get(player)
	if not profile then return false, "noload" end
	local ok, res = TreasureService.TryDig(player.UserId, player, profile)
	if not ok then return false, res end
	MoneyService.Add(player, res.bonus, "dig:" .. res.riddleId)
	profile.cash = MoneyService.Get(player)
	SaveSystem.Save(player)
	UpdateHud:FireClient(player, { type = "treasure_found", riddleId = res.riddleId, level = res.level })
	return true, res
end

function BuyTool.OnServerInvoke(player: Player, tool: string)
	if type(tool) ~= "string" or #tool > 16 then
		return false, "tool_invalid"
	end
	local profile = SaveSystem.Get(player)
	if not profile then return false, "noload" end
	if tool == "shovel" then
		if profile.treasure.hasShovel then return false, "sudah_punya" end
		if not MoneyService.Spend(player, TreasureConfig.Tools.ShovelCost) then
			return false, "koin_kurang"
		end
		InventoryService.GiveShovel(profile)
		profile.cash = MoneyService.Get(player)
		SaveSystem.Save(player)
		return true, "sekop_ok"
	elseif tool == "compass" then
		if profile.treasure.hasCompass then return false, "sudah_punya" end
		if not MoneyService.Spend(player, TreasureConfig.Tools.CompassCost) then
			return false, "koin_kurang"
		end
		InventoryService.GiveCompass(profile)
		profile.cash = MoneyService.Get(player)
		SaveSystem.Save(player)
		return true, "kompas_ok"
	end
	return false, "tool_invalid"
end

-- Alokasi plot permanen per sesi: 1 pemain = 1 plot (Owner = UserId string)
local function assignPlot(p: Player)
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return end
	for _, plot in plots:GetChildren() do
		if plot:IsA("BasePart") and plot.Name:match("^Plot_") then
			local o = plot:FindFirstChild("Owner")
			if o and o.Value == "" then
				o.Value = tostring(p.UserId)
				return
			end
		end
	end
end

local function releasePlot(p: Player)
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return end
	for _, plot in plots:GetChildren() do
		local o = plot and plot:FindFirstChild("Owner")
		if o and o.Value == tostring(p.UserId) then
			o.Value = ""
			-- bersihkan visual crop agar tidak tertinggal
			for _, c in plot:GetChildren() do
				if c.Name == "Crop" then c:Destroy() end
			end
		end
	end
end

Players.PlayerAdded:Connect(function(p)
	Analytics.Join()
	local profile = SaveSystem.Load(p)
	if not profile then
		task.wait(5)
		profile = SaveSystem.Load(p)
	end
	if not profile then
		-- DataStore down: tendang agar data cloud tidak tertimpa default
		p:Kick("Data gagal dimuat. Coba join lagi dalam 1 menit.")
		return
	end
	local sessOk, sessMsg = SaveSystem.ClaimSession(p)
	if not sessOk then
		p:Kick(tostring(sessMsg or "Sesi ganda."))
		return
	end
	InventoryService.Ensure(profile)
	TreasureService.BindUid(p.UserId, profile)
	MoneyService.InitPlayer(p, profile)
	MoneyService.RefreshMultiplier(p, profile)
	Leaderboard.Attach(p, profile)
	StealSystem.LockBase(p, 0, false) -- spawn protection 60s
	assignPlot(p)
	-- kirim offline popup + stok shop
	task.defer(function()
		UpdateHud:FireClient(p, { type = "welcome", offline = profile.offlineEarned or 0, cash = profile.cash })
	end)
end)

-- DevProduct beli (Luck / Unlock)
MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if player and GamepassHandler.OnProductBought(player, info.ProductId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

Players.PlayerRemoving:Connect(function(p)
	releasePlot(p)
	lastPos[p.UserId] = nil
end)

print("[StealKebun] Main loaded")

-- Config.luau — satu tempat untuk balancing mingguan
local Config = {
	ServerSize = 8,
	MaxSlots = 8,

	BaseLockTime = 60, -- +10 per rebirth, +10 jika VIP
	LockPerRebirth = 10,
	VipExtraLock = 10,

	OfflineGrowthCap = 8 * 3600, -- 8 jam
	OfflineMaxPctOfRebirth = 0.5, -- offline tidak boleh >50% syarat rebirth (anti kaya instan)

	SaveKey = "StealKebun_v1",
	AutosaveInterval = 120,

	StartingCash = 100,
	RebirthRequirement = 1_000_000,
	RebirthMultiplierStep = 1, -- +1x per rebirth (1 rebirth = x2)
	MaxRebirthMultiplier = 10,

	StealCooldown = 5,
	StealDistance = 15, -- stud, thief ke item victim
	StealChannelTime = 3, -- harus tahan 3 detik dekat base
	SafeZoneName = "TradePlaza", -- no-steal zone

	IncomeTick = 1,
	MaxCashPerTick = 10_000_000, -- sanity cap anti-inject

	Gamepasses = {
		DoubleMoney = 0, -- 299 R$
		VIP = 0, -- 375 R$
	},
	Products = {
		LuckBoost15m = 0, -- 99 R$
		UnlockInstant = 0, -- 49 R$
	},

	Event = {
		Name = "Hujan Kopi",
		DurationMinutes = 30,
		IncomeMultiplier = 2, -- x2 saat event
		AutoSaturday19WIB = true, -- Sabtu 19:00 WIB (12:00 UTC)
	},

	-- Katalog event (dipilih via ;event <nama> [menit]); auto Sabtu pakai DefaultEvent.
	Events = {
		hujan = { Name = "Hujan Kopi", DurationMinutes = 30, IncomeMultiplier = 2 },
		golden = { Name = "Golden Harvest", DurationMinutes = 20, IncomeMultiplier = 3 },
		rush = { Name = "Treasure Rush", DurationMinutes = 20, IncomeMultiplier = 2, HintDiscount = true },
		meteor = { Name = "Meteor Shower", DurationMinutes = 15, IncomeMultiplier = 4 },
	},
	DefaultEvent = "hujan",

	-- Mutasi: 22 base x 4 = 88 kombinasi tanpa upload 88x (cukup tint + decal varian)
	Mutations = {
		Normal = 1,
		Gold = 5,
		Dark = 3,
		Rainbow = 10,
	},
	MutationRate = { Normal = 70, Gold = 15, Dark = 10, Rainbow = 5 }, -- % saat tanam

	AdminUserIds = {
		-- isi UserId kamu: [123456] = true,
	},
}

return Config

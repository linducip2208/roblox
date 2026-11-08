-- Items.luau — 20 item awal + lookup cepat
local ItemsList = {
	{ Id = "cabai_noob", Name = "Cabai Noob", Rarity = "Common", Cost = 50, CashPerSec = 1, GrowthTime = 30 },
	{ Id = "wortel_goyang", Name = "Wortel Goyang", Rarity = "Common", Cost = 150, CashPerSec = 3, GrowthTime = 60 },
	{ Id = "tomat_gendut", Name = "Tomat Gendut", Rarity = "Common", Cost = 400, CashPerSec = 7, GrowthTime = 120 },
	{ Id = "jagung_rave", Name = "Jagung Rave", Rarity = "Uncommon", Cost = 1200, CashPerSec = 18, GrowthTime = 180 },
	{ Id = "terong_disco", Name = "Terong Disco", Rarity = "Uncommon", Cost = 3000, CashPerSec = 40, GrowthTime = 300 },
	{
		Id = "semangka_mewing",
		Name = "Semangka Mewing",
		Rarity = "Uncommon",
		Cost = 7500,
		CashPerSec = 90,
		GrowthTime = 420,
	},
	{ Id = "pisang_sultan", Name = "Pisang Sultan", Rarity = "Rare", Cost = 15000, CashPerSec = 180, GrowthTime = 600 },
	{ Id = "durian_megar", Name = "Durian Megar", Rarity = "Rare", Cost = 35000, CashPerSec = 350, GrowthTime = 900 },
	{
		Id = "anggur_roblox",
		Name = "Anggur Hacker",
		Rarity = "Rare",
		Cost = 75000,
		CashPerSec = 700,
		GrowthTime = 1200,
	},
	{ Id = "mangga_ohio", Name = "Mangga Ohio", Rarity = "Epic", Cost = 150000, CashPerSec = 1400, GrowthTime = 1500 },
	{
		Id = "apel_brainrot",
		Name = "Apel Brainrot",
		Rarity = "Epic",
		Cost = 300000,
		CashPerSec = 2800,
		GrowthTime = 1800,
	},
	{ Id = "nanas_jet", Name = "Nanas Jet", Rarity = "Epic", Cost = 600000, CashPerSec = 5500, GrowthTime = 2100 },
	{
		Id = "kelapa_godzilla",
		Name = "Kelapa Godzilla",
		Rarity = "Legendary",
		Cost = 1200000,
		CashPerSec = 11000,
		GrowthTime = 2400,
	},
	{
		Id = "melon_skibidi",
		Name = "Melon Skibidi",
		Rarity = "Legendary",
		Cost = 2500000,
		CashPerSec = 22000,
		GrowthTime = 2700,
	},
	{
		Id = "stroberi_tung",
		Name = "Stroberi Tung Tung",
		Rarity = "Legendary",
		Cost = 5000000,
		CashPerSec = 45000,
		GrowthTime = 3000,
	},
	{
		Id = "leci_tralala",
		Name = "Leci Tralala",
		Rarity = "Mythic",
		Cost = 10000000,
		CashPerSec = 90000,
		GrowthTime = 3300,
	},
	{
		Id = "kiwi_bombardilo",
		Name = "Kiwi Bombardilo",
		Rarity = "Mythic",
		Cost = 25000000,
		CashPerSec = 200000,
		GrowthTime = 3600,
	},
	{
		Id = "sirsak_titan",
		Name = "Sirsak Titan",
		Rarity = "Mythic",
		Cost = 50000000,
		CashPerSec = 450000,
		GrowthTime = 3900,
	},
	{
		Id = "sawit_garut",
		Name = "Sawit Garut Emas",
		Rarity = "Secret",
		Cost = 150000000,
		CashPerSec = 1200000,
		GrowthTime = 4200,
	},
	{
		Id = "kopi_gacor",
		Name = "Kopi Gacor Abadi",
		Rarity = "Secret",
		Cost = 500000000,
		CashPerSec = 4000000,
		GrowthTime = 4500,
	},
	-- EVENT SABTU #1 (Hujan Kopi, 2-8 Nov): hanya bisa dibeli saat event aktif
	{
		Id = "kopi_hujan",
		Name = "Kopi Hujan Lebat",
		Rarity = "Event",
		Cost = 500000,
		CashPerSec = 8000,
		GrowthTime = 900,
		EventOnly = true,
	},
	{
		Id = "payung_raksasa",
		Name = "Payung Raksasa",
		Rarity = "Event",
		Cost = 2000000,
		CashPerSec = 25000,
		GrowthTime = 1200,
		EventOnly = true,
	},
}

local ById = {}
for _, it in ItemsList do
	ById[it.Id] = it
end

return {
	List = ItemsList,
	ById = ById,
}

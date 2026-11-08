-- TreasureConfig.luau — 10 teka-teki Indonesia, spawn, reward, hint
local TreasureConfig = {
	Tools = {
		ShovelCost = 5000,
		CompassCost = 3000,
		KeyCost = 0, -- kunci didapat dari riddle, bukan beli
	},
	Hint = {
		CostCoins = 1000,
		CooldownSecs = 120, -- atau bayar koin untuk skip tunggu
		MaxHintsPerRiddle = 2,
	},
	Answer = {
		CooldownSecs = 5,
		MaxFails = 5,
		LockoutSecs = 60,
	},
	Dig = {
		Radius = 8, -- stud dari titik asli
		CooldownSecs = 3,
		NeedShovel = true,
	},
	-- Riddle: question, choices (tampilkan), answerIndex (SERVER ONLY, jangan kirim index ke client),
	-- hint1/hint2 bertahap, zone = nama area yg boleh dikasih ke client, reward
	Riddles = {
		{ Id = "R1", Q = "Aku punya daun tapi bukan pohon, punya sampul tapi bukan buku. Siapakah aku?",
			Choices = {"Pintu", "Meja", "Daun Talas", "Jendela"}, Answer = 1,
			Hint1 = "Benda ini dibuka-tutup setiap hari.", Hint2 = "Jawabannya ada di setiap rumah.",
			Zone = "Plaza Utara", RewardCash = 5000, RewardKey = 1 },
		{ Id = "R2", Q = "Semakin banyak diambil, semakin besar aku. Apakah aku?",
			Choices = {"Lubang", "Ember", "Karung", "Sumur"}, Answer = 1,
			Hint1 = "Kamu butuh sekop untukku.", Hint2 = "Galilah tanah dan lihat.",
			Zone = "Kebun Timur", RewardCash = 8000, RewardKey = 1 },
		{ Id = "R3", Q = "Aku berlari tapi tidak punya kaki, punya mulut tapi tidak bicara. Apakah aku?",
			Choices = {"Angin", "Sungai", "Mobil", "Kuda"}, Answer = 2,
			Hint1 = "Suaranya gemericik.", Hint2 = "Ikan tinggal di dalamnya.",
			Zone = "Sungai Selatan", RewardCash = 12000, RewardKey = 1 },
		{ Id = "R4", Q = "Benda apa yang naik tapi tidak pernah turun?",
			Choices = {"Umur", "Bola", "Layangan", "Asap"}, Answer = 1,
			Hint1 = "Semua pemain punya ini.", Hint2 = "Bertambah setiap tahun.",
			Zone = "Menara Jam", RewardCash = 15000, RewardKey = 1 },
		{ Id = "R5", Q = "Aku punya kota tanpa rumah, hutan tanpa pohon, sungai tanpa air. Apakah aku?",
			Choices = {"Mimpi", "Peta", "Lukisan", "Buku"}, Answer = 2,
			Hint1 = "Buka ini untuk navigasi.", Hint2 = "Kamu melihat peta ini di UI.",
			Zone = "Gua Barat", RewardCash = 20000, RewardKey = 2 },
		{ Id = "R6", Q = "Apa yang selalu datang tapi tidak pernah tiba?",
			Choices = {"Besok", "Paket", "Tamu", "Hujan"}, Answer = 1,
			Hint1 = "Hari ini bukan dia.", Hint2 = "Hari setelah hari ini.",
			Zone = "Pasar Tengah", RewardCash = 25000, RewardKey = 2 },
		{ Id = "R7", Q = "Aku dimakan tapi tidak bisa dimakan balik. Apakah aku?",
			Choices = {"Waktu", "Nasi", "Buah", "Ikan"}, Answer = 1,
			Hint1 = "Jam mengukurnya.", Hint2 = "Tidak bisa diputar balik.",
			Zone = "Dapur Raksasa", RewardCash = 30000, RewardKey = 2 },
		{ Id = "R8", Q = "Punya kunci tapi tidak bisa membuka pintu. Apakah aku?",
			Choices = {"Piano", "Gembok Rusak", "Petani", "Koki"}, Answer = 1,
			Hint1 = "Bunyinya do-re-mi.", Hint2 = "Alat musik tuts.",
			Zone = "Aula Musik", RewardCash = 40000, RewardKey = 2 },
		{ Id = "R9", Q = "Aku punya jantung tapi tidak berdetak. Apakah aku?",
			Choices = {"Artichoke", "Batu", "Boneka", "Robot"}, Answer = 1,
			Hint1 = "Sayuran berlapis.", Hint2 = "Diawali huruf A.",
			Zone = "Hutan Berduri", RewardCash = 60000, RewardKey = 3 },
		{ Id = "R10", Q = "Semakin aku kering, semakin basah yang kubuat. Apakah aku?",
			Choices = {"Handuk", "Payung", "Kipas", "Sabun"}, Answer = 1,
			Hint1 = "Dipakai setelah mandi.", Hint2 = "Menyerap air.",
			Zone = "Pemandian", RewardCash = 100000, RewardKey = 3 },
	},
	-- Titik spawn tetap (nama zona Pl္ots). Saat riddle solved, server pilih 1 + offset acak.
	SpawnPoints = {
		Vector3.new(45, 3, 20), Vector3.new(-50, 3, 35), Vector3.new(20, 3, -55),
		Vector3.new(-30, 3, -40), Vector3.new(60, 3, -10), Vector3.new(-60, 3, -20),
		Vector3.new(10, 3, 60), Vector3.new(-15, 3, 55),
	},
	RandomOffset = 12, -- acak ±12 stud agar tidak fixed
}

return TreasureConfig

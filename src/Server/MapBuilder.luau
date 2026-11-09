-- MapBuilder.luau -- bangun map otomatis, IDEMPOTEN (aman dipanggil ulang).
-- 8 plot melingkar (validasi per nama Plot_1..8) + tanah + plaza + shop + spawn + rambu + pohon.
-- Semua bagian dicek satu per satu; tidak ada duplikat saat rebuild.
local MapBuilder = {}

local GRASS = Color3.fromRGB(85, 170, 85)
local TRUNK = Color3.fromRGB(110, 70, 40)
local LEAF = Color3.fromRGB(60, 160, 80)

function MapBuilder.Build()
	local light = game:GetService("Lighting")
	light.ClockTime = 14
	light.Brightness = 2
	light.Ambient = Color3.fromRGB(120, 120, 130)
	light.OutdoorAmbient = Color3.fromRGB(150, 160, 180)
	light.FogEnd = 900

	-- Tanah dasar: tanpanya pemain jatuh ke void (spawn tidak di atas plot).
	local g = workspace:FindFirstChild("GroundKebun")
	if not g then
		g = Instance.new("Part")
		g.Name = "GroundKebun"
		g.Parent = workspace
	end
	g.Size = Vector3.new(400, 1, 400)
	g.Position = Vector3.new(0, 0, 0)
	g.Anchored = true
	g.CanCollide = true -- tanah harus bisa dipijak
	g.Color = Color3.fromRGB(70, 150, 70)
	g.Material = Enum.Material.Grass

	if workspace:FindFirstChild("Plots") == nil then
		local f = Instance.new("Folder")
		f.Name = "Plots"
		f.Parent = workspace
	end
	local plots = workspace:FindFirstChild("Plots")

	-- Validasi per nama: buat yang hilang saja, perbaiki Owner/LockPole yang rusak.
	local radius = 60
	for i = 1, 8 do
		local pname = "Plot_" .. i
		local base = plots:FindFirstChild(pname)
		if not base then
			local angle = (i - 1) / 8 * math.pi * 2
			base = Instance.new("Part")
			base.Name = pname
			base.Size = Vector3.new(16, 1, 16)
			base.Position = Vector3.new(math.cos(angle) * radius, 1, math.sin(angle) * radius)
			base.Color = GRASS
			base.Material = Enum.Material.Grass
			base.Parent = plots
		end
		-- Perbaiki properti bila folder/plot parsial atau properti diubah manual.
		base.Anchored = true
		base.CanCollide = true -- plot harus bisa dipijak pemain pemiliknya
		if not base:FindFirstChild("Owner") then
			local owner = Instance.new("StringValue")
			owner.Name = "Owner"
			owner.Value = ""
			owner.Parent = base
		end
		local pole = base:FindFirstChild("LockPole")
		if not pole then
			pole = Instance.new("Part")
			pole.Name = "LockPole"
			pole.Size = Vector3.new(1, 8, 1)
			pole.Position = base.Position + Vector3.new(6, 4, 6)
			pole.Color = Color3.fromRGB(255, 255, 255)
			pole.Material = Enum.Material.SmoothPlastic
			pole.Parent = base
		end
		pole.Anchored = true
		pole.CanCollide = false -- tiang indikator: jangan halangi jalan
	end

	-- TradePlaza = safezone no-steal (nama HARUS sama dengan Config.SafeZoneName).
	local plaza = workspace:FindFirstChild("TradePlaza")
	if not plaza then
		plaza = Instance.new("Part")
		plaza.Name = "TradePlaza"
		plaza.Parent = workspace
	end
	plaza.Size = Vector3.new(30, 1, 30)
	plaza.Position = Vector3.new(0, 1, 0)
	plaza.Anchored = true
	plaza.CanCollide = true
	plaza.Color = Color3.fromRGB(100, 150, 255)
	plaza.Material = Enum.Material.SmoothPlastic

	-- Shop
	local shop = workspace:FindFirstChild("Shop")
	if not shop then
		shop = Instance.new("Part")
		shop.Name = "Shop"
		shop.Parent = workspace
	end
	shop.Size = Vector3.new(12, 6, 12)
	shop.Position = Vector3.new(0, 4, -25)
	shop.Anchored = true
	shop.CanCollide = true -- balok toko: rintangan, pembelian via UI bukan masuk ke dalam
	shop.Color = Color3.fromRGB(255, 200, 50)
	shop.Material = Enum.Material.WoodPlanks

	-- Spawn DI ATAS plaza (bukan di luar) agar tidak jatuh ke void.
	local sp = workspace:FindFirstChild("SpawnLocation")
	if not sp then
		sp = Instance.new("SpawnLocation")
		sp.Parent = workspace
	end
	sp.Size = Vector3.new(6, 1, 6)
	sp.Position = Vector3.new(0, 4, 5)
	sp.Anchored = true
	sp.CanCollide = true
	sp.Enabled = true
	sp.Neutral = true -- tanpa tim: semua pemain boleh spawn di sini
	sp.AllowTeamChangeOnTouch = false

	MapBuilder.Sign("Rambu_Shop", Vector3.new(0, 12, -25), "TOKO - beli bibit di sini")
	MapBuilder.Sign("Rambu_Plaza", Vector3.new(0, 9, 0), "PLAZA AMAN - tidak bisa dicuri")
	MapBuilder.Sign("Rambu_Spawn", Vector3.new(0, 11, 5), "SPAWN")
	MapBuilder.Trees()
end

-- Pohon hias di tepi map (idempoten per nama, CanCollide false agar ringan & tak menghalangi).
function MapBuilder.Trees()
	local folder = workspace:FindFirstChild("TreesKebun")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TreesKebun"
		folder.Parent = workspace
	end
	for i = 1, 8 do
		local angle = (i - 1) / 8 * math.pi * 2 + 0.4
		local x, z = math.cos(angle) * 95, math.sin(angle) * 95
		local trunk = folder:FindFirstChild("Trunk" .. i)
		if not trunk then
			trunk = Instance.new("Part")
			trunk.Name = "Trunk" .. i
			trunk.Shape = Enum.PartType.Cylinder
			trunk.Size = Vector3.new(8, 2, 2) -- silinder: sumbu X = tinggi
			trunk.CFrame = CFrame.new(x, 4.5, z)
			trunk.Color = TRUNK
			trunk.Material = Enum.Material.Wood
			trunk.Parent = folder
		end
		trunk.Anchored = true
		trunk.CanCollide = false
		local leaves = folder:FindFirstChild("Leaves" .. i)
		if not leaves then
			leaves = Instance.new("Part")
			leaves.Name = "Leaves" .. i
			leaves.Shape = Enum.PartType.Ball
			leaves.Size = Vector3.new(10, 10, 10)
			leaves.Position = Vector3.new(x, 12, z)
			leaves.Color = LEAF
			leaves.Material = Enum.Material.Grass
			leaves.Parent = folder
		end
		leaves.Anchored = true
		leaves.CanCollide = false
	end
end

-- Rambu apung: BillboardGui + tiang. Idempoten (tidak dobel saat rebuild,
-- GUI dibangun ulang bila tiang ada tapi GUI terhapus).
function MapBuilder.Sign(name: string, pos: Vector3, text: string)
	local pole = workspace:FindFirstChild(name)
	if not pole then
		pole = Instance.new("Part")
		pole.Name = name
		pole.Size = Vector3.new(0.6, 8, 0.6)
		pole.Position = pos - Vector3.new(0, 2, 0)
		pole.Color = Color3.fromRGB(90, 60, 30)
		pole.Material = Enum.Material.Wood
		pole.Parent = workspace
	end
	pole.Anchored = true
	pole.CanCollide = false
	if pole:FindFirstChildOfClass("BillboardGui") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 260, 0, 60)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.AlwaysOnTop = false
	gui.Parent = pole
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundColor3 = Color3.fromRGB(34, 54, 83)
	label.BackgroundTransparency = 0.1
	label.TextColor3 = Color3.fromRGB(255, 200, 60)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

return MapBuilder

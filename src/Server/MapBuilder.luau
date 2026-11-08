-- MapBuilder.luau — bangun map otomatis agar langsung Play tanpa build manual
-- 8 plot melingkar + TradePlaza (safezone) + Shop + Spawn
local MapBuilder = {}

function MapBuilder.Build()
	-- Lighting ceria konsisten (aman dijalanin tiap start; tidak menimpa pilihan Studio manual? menimpa — by design agar seragam)
	local light = game:GetService("Lighting")
	light.ClockTime = 14
	light.Brightness = 2
	light.Ambient = Color3.fromRGB(120, 120, 130)
	light.OutdoorAmbient = Color3.fromRGB(150, 160, 180)
	light.FogEnd = 900

	if workspace:FindFirstChild("Plots") == nil then
		local f = Instance.new("Folder")
		f.Name = "Plots"
		f.Parent = workspace
	end
	local plots = workspace:FindFirstChild("Plots")
	if #plots:GetChildren() >= 8 then
		return
	end -- sudah dibangun

	local radius = 60
	for i = 1, 8 do
		local angle = (i - 1) / 8 * math.pi * 2
		local base = Instance.new("Part")
		base.Name = "Plot_" .. i
		base.Size = Vector3.new(16, 1, 16)
		base.Position = Vector3.new(math.cos(angle) * radius, 1, math.sin(angle) * radius)
		base.Anchored = true
		base.Color = Color3.fromRGB(85, 170, 85)
		base.Parent = plots

		local owner = Instance.new("StringValue")
		owner.Name = "Owner"
		owner.Value = ""
		owner.Parent = base

		-- tiang lock indicator
		local pole = Instance.new("Part")
		pole.Name = "LockPole"
		pole.Size = Vector3.new(1, 8, 1)
		pole.Position = base.Position + Vector3.new(6, 4, 6)
		pole.Anchored = true
		pole.Parent = base
	end

	-- TradePlaza = safezone no-steal
	if not workspace:FindFirstChild("TradePlaza") then
		local plaza = Instance.new("Part")
		plaza.Name = "TradePlaza"
		plaza.Size = Vector3.new(30, 1, 30)
		plaza.Position = Vector3.new(0, 1, 0)
		plaza.Anchored = true
		plaza.Color = Color3.fromRGB(100, 150, 255)
		plaza.Parent = workspace
	end

	-- Shop
	if not workspace:FindFirstChild("Shop") then
		local shop = Instance.new("Part")
		shop.Name = "Shop"
		shop.Size = Vector3.new(12, 6, 12)
		shop.Position = Vector3.new(0, 4, -25)
		shop.Anchored = true
		shop.Color = Color3.fromRGB(255, 200, 50)
		shop.Parent = workspace
	end

	-- Spawn
	if not workspace:FindFirstChild("SpawnLocation") then
		local sp = Instance.new("SpawnLocation")
		sp.Position = Vector3.new(0, 5, 20)
		sp.Anchored = true
		sp.Parent = workspace
	end
end

return MapBuilder

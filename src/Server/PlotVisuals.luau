-- PlotVisuals.luau — tampilkan tanaman sebagai Part warna per rarity + progress
local PlotVisuals = {}
local rarityColor = {
	Common = Color3.fromRGB(120, 200, 120),
	Uncommon = Color3.fromRGB(80, 180, 255),
	Rare = Color3.fromRGB(150, 100, 255),
	Epic = Color3.fromRGB(255, 100, 200),
	Legendary = Color3.fromRGB(255, 200, 50),
	Mythic = Color3.fromRGB(255, 50, 50),
	Secret = Color3.fromRGB(0, 255, 255),
	Event = Color3.fromRGB(150, 80, 40),
}

function PlotVisuals.Refresh(plotBase: BasePart, slots: any, Items: any, PlotManager: any)
	-- hapus visual lama
	for _, c in plotBase:GetChildren() do
		if c.Name == "Crop" then
			c:Destroy()
		end
	end
	local AssetMap = nil
	pcall(function()
		AssetMap = require(game.ReplicatedStorage.Shared:WaitForChild("AssetMap"))
	end)
	local i = 0
	for _, slot in slots do
		local def = Items.ById[slot.itemId]
		if def then
			i += 1
			local grown = PlotManager.IsGrown(slot)
			local p = Instance.new("Part")
			p.Name = "Crop"
			p.Shape = Enum.PartType.Ball
			p.Size = grown and Vector3.new(3, 3, 3) or Vector3.new(1.5, 1.5, 1.5)
			p.Color = rarityColor[def.Rarity] or Color3.new(1, 1, 1)
			p.Transparency = grown and 0 or 0.5
			p.Anchored = true
			p.CanCollide = false
			-- susun grid 4x2 di atas plot
			local ox = ((i - 1) % 4 - 1.5) * 3.5
			local oz = (math.floor((i - 1) / 4) - 0.5) * 4
			p.Position = plotBase.Position + Vector3.new(ox, 2.5, oz)
			p.Parent = plotBase
			-- jika AssetMap sudah diisi, tempel Decal (tetap jalan tanpa aset)
			if AssetMap then
				local mutKey = (slot.mutation and slot.mutation ~= "Normal")
						and (slot.itemId .. "-" .. string.lower(slot.mutation))
					or nil
				local id = (mutKey and AssetMap.Get(mutKey)) or AssetMap.Get(slot.itemId)
				if id then
					local d = Instance.new("Decal")
					d.Texture = id
					d.Face = Enum.NormalId.Front
					d.Parent = p
				end
			end
			-- label nama biar bisa pilih curi
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.new(0, 120, 0, 30)
			gui.StudsOffset = Vector3.new(0, 2.5, 0)
			gui.Parent = p
			local tl = Instance.new("TextLabel")
			tl.Size = UDim2.new(1, 0, 1, 0)
			tl.BackgroundTransparency = 1
			tl.TextScaled = true
			local mut = slot.mutation and slot.mutation ~= "Normal" and (" [" .. slot.mutation .. "]") or ""
			tl.Text = def.Name .. mut .. (grown and " ✅" or " 🌱")
			tl.Parent = gui
		end
	end
end

return PlotVisuals

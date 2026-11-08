-- UiIcons.luau -- tempel ikon 28px di kiri tombol, HANYA jika Asset ID terisi.
-- Sebelum upload: tidak ada ImageLabel dibuat (tanpa kotak rusak).
local AssetMap = require(script.Parent.AssetMap)

local UiIcons = {}

function UiIcons.Attach(button: GuiButton, assetKey: string)
	local id = AssetMap.Get(assetKey)
	if not id then
		return false
	end
	local img = Instance.new("ImageLabel")
	img.Name = "Icon"
	img.Size = UDim2.new(0, 28, 0, 28)
	img.Position = UDim2.new(0, 4, 0.5, -14)
	img.BackgroundTransparency = 1
	img.Image = id
	img.Parent = button
	return true
end

return UiIcons

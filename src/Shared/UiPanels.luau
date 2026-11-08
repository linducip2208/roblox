-- UiPanels.luau -- satu-satunya pengatur visibilitas panel (hindari GUI saling timpa).
-- Panel mendaftar sekali; HUD + tombol internal memanggil Toggle/SetVisible yang sama.
-- Berjalan di client (Shared direplikasi, state per-client).
local UiPanels = {}
local panels: { [string]: { set: (boolean) -> (), visible: boolean } } = {}
local order: { string } = {}

function UiPanels.Register(name: string, setVisible: (boolean) -> (), initial: boolean)
	panels[name] = { set = setVisible, visible = initial }
	table.insert(order, name)
	setVisible(initial)
end

function UiPanels.SetVisible(name: string, v: boolean)
	local p = panels[name]
	if not p then
		return false
	end
	if v then
		-- Eksklusif: satu panel utama aktif dalam satu waktu.
		for other, q in pairs(panels) do
			if other ~= name and q.visible then
				q.visible = false
				q.set(false)
			end
		end
	end
	p.visible = v
	p.set(v)
	return true
end

function UiPanels.Toggle(name: string): boolean
	local p = panels[name]
	if not p then
		return false
	end
	return UiPanels.SetVisible(name, not p.visible)
end

function UiPanels.IsVisible(name: string): boolean
	local p = panels[name]
	return p ~= nil and p.visible
end

function UiPanels.Names(): { string }
	return order
end

return UiPanels

-- UiPanels.luau -- satu-satunya pengatur visibilitas panel (hindari GUI saling timpa).
-- Panel mendaftar sekali; HUD + tombol internal memanggil Toggle/SetVisible yang sama.
-- Berjalan di client (Shared direplikasi, state per-client).
local UiPanels = {}
local panels: { [string]: { set: (boolean) -> (), visible: boolean } } = {}
local order: { string } = {}

function UiPanels.Register(name: string, setVisible: (boolean) -> (), initial: boolean)
	if panels[name] ~= nil then
		warn("[UiPanels] registrasi ganda diabaikan: " .. tostring(name))
		return
	end
	panels[name] = { set = setVisible, visible = false }
	table.insert(order, name)
	-- lewat SetVisible agar eksklusivitas berlaku sejak awal, bukan hanya saat toggle
	UiPanels.SetVisible(name, initial)
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

-- Toggle panel yang belum terdaftar = diagnostik jelas (bukan silent fail).
function UiPanels.Toggle(name: string): boolean
	local p = panels[name]
	if not p then
		warn("[UiPanels] Toggle panel tak terdaftar: " .. tostring(name))
		return false
	end
	return UiPanels.SetVisible(name, not p.visible)
end

function UiPanels.IsVisible(name: string): boolean
	local p = panels[name]
	return p ~= nil and p.visible
end

-- Bersihkan registrasi saat GUI dihancurkan (hindari callback basi + leak).
function UiPanels.Unregister(name: string)
	panels[name] = nil
	for i, n in order do
		if n == name then
			table.remove(order, i)
			break
		end
	end
end

function UiPanels.Names(): { string }
	return order
end

return UiPanels

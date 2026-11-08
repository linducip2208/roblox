-- RedeemCode.luau — kode redeem sekali pakai per player
local RedeemCode = {}
local CODES = {
	RILIS100K = 100000,
	HUJANKOPI = 50000,
	GACOR2026 = 250000,
}

function RedeemCode.Redeem(profile, code: string): (boolean, number | string)
	code = code:upper():gsub("%s+", "")
	local amount = CODES[code]
	if not amount then
		return false, "kode_salah"
	end
	profile.redeemed = profile.redeemed or {}
	if profile.redeemed[code] then
		return false, "sudah_dipakai"
	end
	profile.redeemed[code] = true
	return true, amount
end

return RedeemCode

--[=[
	@class CurrencyUtil

	Formats currency amounts for display — the fast-counting HUD reads through this.
	`abbreviate` renders large values with a magnitude suffix (`1234` → `"1.23K"`,
	`5_600_000` → `"5.6M"`); values under 1000 render as a plain integer.
]=]

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

--[=[
	@within CurrencyUtil
	@param value number -- the amount to format
	@return string -- the abbreviated amount (e.g. `1234` → `"1.23K"`)
]=]
local function abbreviate(value: number): string
	local negative = value < 0
	value = math.abs(value)

	local order = 0
	while value >= 1000 and order < #SUFFIXES - 1 do
		value /= 1000
		order += 1
	end

	local text
	if order == 0 then
		text = tostring(math.floor(value))
	else
		local rounded
		if value >= 100 then
			rounded = math.floor(value)
		elseif value >= 10 then
			rounded = math.floor(value * 10) / 10
		else
			rounded = math.floor(value * 100) / 100
		end
		text = tostring(rounded) .. SUFFIXES[order + 1]
	end

	return (if negative then "-" else "") .. text
end

return {
	abbreviate = abbreviate,
}

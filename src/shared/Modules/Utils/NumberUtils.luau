local function abbreviateTime(value: number): string
	local s = math.sign(value)
	value = math.abs(value)
	local prefixes = {
		[4] = "T",
		[3] = "G",
		[2] = "M",
		[1] = "k",
		[0] = " ",
		[-1] = "m",
		[-2] = "u",
		[-3] = "n",
		[-4] = "p",
	}

	local order = 0

	while value >= 1000 do
		order += 1
		value /= 1000
	end

	while value ~= 0 and value < 1 do
		order -= 1
		value *= 1000
	end

	if value >= 100 then
		value = math.floor(value)
	elseif value >= 10 then
		value = math.floor(value * 1e1) / 1e1
	elseif value >= 1 then
		value = math.floor(value * 1e2) / 1e2
	end

	return value * s .. prefixes[order] .. "s"
end

--[=[
	@within NumberUtils
	@param value number -- the integer to format
	@return string -- the value with thousands separated by commas (e.g. `10640` → `"10,640"`)
]=]
local function commas(value: number): string
	local sign, digits = string.match(tostring(math.floor(value)), "^(%-?)(%d+)$")
	local formatted = (digits :: string):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return sign .. formatted
end

return {
	abbreviateTime = abbreviateTime,
	commas = commas,
}

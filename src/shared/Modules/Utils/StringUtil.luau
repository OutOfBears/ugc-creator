--[=[
	@class StringUtil

	Helpers for normalizing strings.
]=]

--[=[
	@within StringUtil
	@param name string -- a name, optionally separated by spaces, underscores, or hyphens
	@return string -- the name in camelCase (e.g. "SuperLeap" -> "superLeap", "attack_heavy" -> "attackHeavy")

	Splits the name on whitespace and `_`/`-` separators, then joins the words by lowercasing the
	first word's initial and capitalizing each following word's initial. Interior casing is
	preserved, so existing PascalCase names collapse to camelCase without a separator.
]=]
local function formatName(name: string): string
	local result = ""

	for word in name:gmatch("[^%s_%-]+") do
		if result == "" then
			result = word:sub(1, 1):lower() .. word:sub(2)
		else
			result ..= word:sub(1, 1):upper() .. word:sub(2)
		end
	end

	return result
end

return {
	formatName = formatName,
}

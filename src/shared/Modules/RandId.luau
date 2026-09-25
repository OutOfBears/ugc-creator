local HttpService = game:GetService("HttpService")

-- Incase we want to add more functionality to this in the future, such as generating shorter ids or adding a prefix to the id, we can just change it here instead of changing it everywhere in the codebase where we generate a new id for an instance
local function generateId()
	return HttpService:GenerateGUID(false)
end

local function getRandomFromId(id: string)
	local hash = 0

	for i = 1, #id do
		hash = bit32.band(hash * 31 + string.byte(id, i), 0xFFFFFFFF)
	end

	return Random.new(hash)
end

local function getSeed()
	return math.random(1, 2 ^ 31 - 1)
end

return {
	generateId = generateId,
	getRandomFromId = getRandomFromId,
	getSeed = getSeed,
}

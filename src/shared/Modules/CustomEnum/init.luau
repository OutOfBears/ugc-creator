local EnumCreator = require("@self/EnumCreator")

local CustomEnum = {}

-- Locking the Enums table to prevent modification
setmetatable(CustomEnum, {
	__index = function(_, key: string)
		error(`"{key}" is not a valid member of "Enums"`, 3)
	end,
	__tostring = function()
		return "Enums"
	end,
})

table.freeze(CustomEnum)

return CustomEnum

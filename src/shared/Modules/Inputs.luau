local InputObject = require("./InputObject")
local Inputs = require("../Data/Inputs")

export type Input = InputObject.Input

local allInputs = {} :: { [string]: Input }

for name, data in Inputs do
	allInputs[name] = InputObject.fromData(data)
end

table.freeze(allInputs)
return allInputs

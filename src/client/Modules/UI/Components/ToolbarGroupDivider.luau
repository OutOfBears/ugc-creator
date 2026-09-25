local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local StyleConsts = require("../Style/StyleConsts")

--[=[
	@class ToolbarGroupDivider
	@client

	Simple frame used as a visual divider between buttons in a toolbar group.

	@return Frame -- the divider
]=]
local function ToolbarGroupDivider(): Frame
	return Create("Frame", {
		Name = "Divider",
		Tags = { StyleConsts.tags.Divider },
	}) :: Frame
end

return ToolbarGroupDivider

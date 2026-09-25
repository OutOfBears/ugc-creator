local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local StyleConsts = require("../Style/StyleConsts")

--[=[
	@class Overlay
	@client

	Input-sinking overlay used to provide contrast behind modals. It is a `TextButton` purely so it
	swallows input; [StyleRules] strips every button affordance back off it.

	@return TextButton -- the overlay
]=]
local function Overlay(): TextButton
	return Create("TextButton", {
		Name = "Overlay",
		Text = "",
		Tags = { StyleConsts.tags.Overlay },
	}) :: TextButton
end

return Overlay

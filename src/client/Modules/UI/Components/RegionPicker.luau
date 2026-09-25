local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local HorizontalPillbar = require("./HorizontalPillbar")
local StyleConsts = require("../Style/StyleConsts")

--[=[
	@class RegionPicker
	@client

	A [HorizontalPillbar] of region icons, sorted by [StyleConsts].regionOrdering so the whole model
	always comes first. Used by the fill and sticker tool UIs.

	@param regionParts { string } -- region names to offer; sorted in place
	@param onRegionSelectedCallback (regionName: string) -> () -- fired with the picked region
	@return Frame -- the pillbar frame
]=]
local function RegionPicker(regionParts: { string }, onRegionSelectedCallback: (string) -> ()): Frame
	table.sort(regionParts, function(a, b)
		return StyleConsts.regionOrdering[a] < StyleConsts.regionOrdering[b]
	end)

	local buttonInfos = {}

	for _, partName in regionParts do
		table.insert(buttonInfos, {
			iconId = CreationIcons.regionIcons[partName],
			callback = function()
				onRegionSelectedCallback(partName)
			end,
		})
	end

	return HorizontalPillbar(buttonInfos).frame
end

return RegionPicker

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseTile = require("./BaseTile")
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local IconButton = require("./IconButton")
local StyleConsts = require("../Style/StyleConsts")

--[=[
	@class TileGrid
	@client

	Grid of interactive [BaseTile]s, laid out in the order of the infos passed in. Used for the
	sticker and kitbashing pickers.

	@param gridButtonInfos { IconButton.IconButtonInfo } -- one entry per tile, in display order
	@return Frame -- the grid frame
]=]
local function TileGrid(gridButtonInfos: { IconButton.IconButtonInfo }): Frame
	local frame = Create("Frame", {
		Name = "TileGridFrame",
		Tags = { StyleConsts.tags.TileGrid },
	}) :: Frame

	for i, info in gridButtonInfos do
		local tile = BaseTile(info.iconId, info.callback)
		tile.LayoutOrder = i
		tile.Parent = frame
	end

	return frame
end

return TileGrid

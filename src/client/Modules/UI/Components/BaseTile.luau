local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local IconButton = require("./IconButton")
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")

--[=[
	@class BaseTile
	@client

	Generic interactive tile displaying a thumbnail, for use in a grid. Used for stickers and
	kitbashing.

	@param imageAssetId string? -- thumbnail to show; without one the tile stays empty and inert
	@param onButtonActivated (() -> ())? -- fired when the tile is pressed
	@return Frame -- the tile frame
]=]
local function BaseTile(imageAssetId: string?, onButtonActivated: (() -> ())?): Frame
	local frame = Create("Frame", {
		Name = "BaseTile",
		Tags = { StyleConsts.tags.BaseTile },
	}) :: Frame

	if not imageAssetId then
		return frame
	end

	local button = IconButton(imageAssetId :: string, onButtonActivated)
	StyleUtils.addStyleTag(button, StyleConsts.tags.BaseTileButton)
	button.Parent = frame

	return frame
end

return BaseTile

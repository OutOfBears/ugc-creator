local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseTile = require("./BaseTile")
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local IconButton = require("./IconButton")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")

export type BaseTileInfo = {
	imageAssetId: string?,
	callback: () -> (),
}

export type AppliedItemDetails = {
	textureId: string,
}

export type TileFrameInfo = {
	frame: Frame,
	hasButton: boolean,
	callback: () -> (),
}

export type MiniBaseTileGroup = {
	-- vars
	frame: Frame,
	tileFrameInfos: { TileFrameInfo },
	maid: Maid.Maid,
	-- methods
	updateSelection: (self: MiniBaseTileGroup, currentlySelectedIndex: number) -> (),
	updateTiles: (
		self: MiniBaseTileGroup,
		appliedItems: { AppliedItemDetails },
		currentlySelectedIndex: number
	) -> (),
	destroy: (self: MiniBaseTileGroup) -> (),
}

--[=[
	@class MiniBaseTileGroup
	@client

	A fixed row of mini tiles showing which stickers or add-ons are applied, one selectable at a
	time. The tiles are created empty and only grow a button once `updateTiles` is given an item for
	that slot.

	@param baseTiles { BaseTileInfo } -- one entry per slot, in display order
	@return MiniBaseTileGroup
]=]
local function MiniBaseTileGroup(baseTiles: { BaseTileInfo }): MiniBaseTileGroup
	local maid = Maid.new()
	local object = {} :: MiniBaseTileGroup

	object.maid = maid
	object.tileFrameInfos = {}

	object.frame = maid:add(Create("Frame", {
		Name = "MiniBaseTileGroup",
		Tags = { StyleConsts.tags.MiniBaseTileGroup },
	}) :: Frame)

	--[=[
		@within MiniBaseTileGroup
		@param currentlySelectedIndex number -- the tile to mark as selected
	]=]
	function object:updateSelection(currentlySelectedIndex: number)
		for i, baseTile in self.tileFrameInfos do
			if i == currentlySelectedIndex then
				StyleUtils.addStyleTag(baseTile.frame, StyleConsts.tags.MiniBaseTileSelected)
			else
				StyleUtils.removeStyleTag(baseTile.frame, StyleConsts.tags.MiniBaseTileSelected)
			end
		end
	end

	--[=[
		@within MiniBaseTileGroup
		@param appliedItems { AppliedItemDetails } -- items filling the slots, from the first slot on
		@param currentlySelectedIndex number -- the tile to mark as selected afterwards
	]=]
	function object:updateTiles(appliedItems: { AppliedItemDetails }, currentlySelectedIndex: number)
		for i, baseTile in self.tileFrameInfos do
			if appliedItems[i] then
				local imageAssetId = appliedItems[i].textureId

				if baseTile.hasButton then
					local button = baseTile.frame:FindFirstChildWhichIsA("TextButton")
					if button then
						local icon = button:FindFirstChildWhichIsA("ImageLabel")
						if not icon then
							warn("MiniBaseTileGroup:updateTiles - missing ImageLabel in IconButton")
							continue
						end

						if icon.Image ~= imageAssetId then
							icon.Image = imageAssetId
						end
					end
				else
					baseTile.hasButton = true

					local button = IconButton(imageAssetId, baseTile.callback)
					StyleUtils.addStyleTag(button, StyleConsts.tags.BaseTileButton)
					button.Parent = baseTile.frame
				end
			elseif baseTile.hasButton then
				local button = baseTile.frame:FindFirstChildWhichIsA("TextButton")
				if button then
					button:Destroy()
				end

				baseTile.hasButton = false
			end
		end

		self:updateSelection(currentlySelectedIndex)
	end

	function object:destroy()
		maid:doCleaning()
	end

	for i, baseTileInfo in baseTiles do
		local baseTile = BaseTile(baseTileInfo.imageAssetId, baseTileInfo.callback)
		baseTile.LayoutOrder = i
		StyleUtils.addStyleTag(baseTile, StyleConsts.tags.MiniBaseTile)
		baseTile.Parent = object.frame

		table.insert(object.tileFrameInfos, {
			frame = baseTile,
			hasButton = false,
			callback = function()
				baseTileInfo.callback()
				object:updateSelection(i)
			end,
		})
	end

	return object
end

return MiniBaseTileGroup

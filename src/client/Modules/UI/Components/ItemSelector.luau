local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Counter = require("./Counter")
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local MiniBaseTileGroup = require("./MiniBaseTileGroup")
local StyleConsts = require("../Style/StyleConsts")

export type ItemSelector = {
	-- vars
	frame: Frame,
	counter: Counter.Counter,
	tileGroup: MiniBaseTileGroup.MiniBaseTileGroup,
	maid: Maid.Maid,
	-- methods
	updateProgress: (
		self: ItemSelector,
		appliedItemInfos: { MiniBaseTileGroup.AppliedItemDetails },
		selectedIndex: number
	) -> (),
	destroy: (self: ItemSelector) -> (),
}

--[=[
	@class ItemSelector
	@client

	A scrollable row of "equipped" item thumbnails alongside a [Counter]. Wraps a
	[MiniBaseTileGroup] with one slot per addable item.

	@param maxAddable number -- how many slots to lay out
	@param onClickTileCallback (index: number) -> () -- fired with the slot index that was pressed
	@return ItemSelector
]=]
local function ItemSelector(maxAddable: number, onClickTileCallback: (number) -> ()): ItemSelector
	local maid = Maid.new()
	local object = {} :: ItemSelector

	object.maid = maid

	object.frame = maid:add(Create("Frame", {
		Tags = { StyleConsts.tags.ItemSelectorFrame },
	}) :: Frame)

	local selectorScrollFrame = Create("ScrollingFrame", {
		Tags = { StyleConsts.tags.ItemSelectorScrollFrame },
	})

	Create("Frame", {
		LayoutOrder = 1,
		Tags = { StyleConsts.tags.ItemSelectorFlexFrame },
		Children = { selectorScrollFrame },
		Parent = object.frame,
	})

	local selectorTiles = {}
	for i = 1, maxAddable do
		table.insert(selectorTiles, {
			callback = function()
				onClickTileCallback(i)
			end,
		})
	end

	object.tileGroup = maid:add(MiniBaseTileGroup(selectorTiles))
	object.tileGroup.frame.Name = "TileGroup"
	object.tileGroup.frame.Parent = selectorScrollFrame

	object.counter = maid:add(Counter(maxAddable))
	object.counter.frame.LayoutOrder = 2
	object.counter.frame.Parent = object.frame

	--[=[
		@within ItemSelector
		@param appliedItemInfos { MiniBaseTileGroup.AppliedItemDetails } -- the items currently applied
		@param selectedIndex number -- the slot to mark as selected
	]=]
	function object:updateProgress(appliedItemInfos: { MiniBaseTileGroup.AppliedItemDetails }, selectedIndex: number)
		self.counter:updateProgress(#appliedItemInfos)
		self.tileGroup:updateTiles(appliedItemInfos, selectedIndex)
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return ItemSelector

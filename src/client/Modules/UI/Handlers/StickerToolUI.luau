local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local ItemSelector = require("../Components/ItemSelector")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Panel = require("../Components/Panel")
local Stickers = require(ReplicatedStorage.Shared.Data.Stickers)
local StyleConsts = require("../Style/StyleConsts")
local TileGrid = require("../Components/TileGrid")

export type StickerToolUI = {
	-- vars
	stickerData: Stickers.Stickers,
	stickerTool: any,
	itemSelector: ItemSelector.ItemSelector,
	panel: Panel.Panel,
	maid: Maid.Maid,
	-- methods
	updateProgress: (self: StickerToolUI) -> (),
	open: (self: StickerToolUI) -> (),
	close: (self: StickerToolUI) -> (),
	destroy: (self: StickerToolUI) -> (),
}

--[=[
	@class StickerToolUI
	@client

	The sticker panel: a picker for the applied sticker layers and a grid of stickers to stamp.
	Patterning lives in [StickerPatternToolUI] instead. Owned by [EditingUI].
]=]
local function StickerToolUI(
	onClosePanelCallback: () -> (),
	onDeleteCallback: () -> (),
	stickerData: Stickers.Stickers,
	stickerTool: any
): StickerToolUI
	local maid = Maid.new()
	local object = {} :: StickerToolUI

	object.stickerData = stickerData
	object.stickerTool = stickerTool
	object.maid = maid

	object.itemSelector = maid:add(ItemSelector(CreationConfig.maxStickerLayers, function(index: number)
		object.stickerTool:selectSticker(index)
	end))

	local scrollingFrame = Create("ScrollingFrame", {
		Tags = { StyleConsts.tags.ScrollFrame },
	})

	local tileInfos = {}

	for _, sticker in object.stickerData do
		local info = {
			iconId = sticker.textureId,
			callback = function()
				object.stickerTool:applySticker(sticker.textureId)
				object:updateProgress()
			end,
		}
		table.insert(tileInfos, info)
	end

	local grid = TileGrid(tileInfos)
	grid.Name = "StickerGrid"
	grid.Parent = scrollingFrame

	object.panel = maid:add(
		Panel("Stickers", onClosePanelCallback, onDeleteCallback, { object.itemSelector.frame, scrollingFrame })
	)
	object.panel.frame.Name = "StickerToolPanel"
	object.panel.frame.Visible = false

	--[=[
		@within StickerToolUI

		Re-reads the tool's applied stickers so the layer picker matches what is on the creation.
	]=]
	function object:updateProgress()
		self.itemSelector:updateProgress(self.stickerTool.appliedStickers, self.stickerTool.currentlySelectedSticker)
	end

	--[=[
		@within StickerToolUI
	]=]
	function object:open()
		self.panel.frame.Visible = true
		self:updateProgress()
	end

	--[=[
		@within StickerToolUI
	]=]
	function object:close()
		self.panel.frame.Visible = false
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return StickerToolUI

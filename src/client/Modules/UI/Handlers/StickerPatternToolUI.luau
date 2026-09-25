local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Panel = require("../Components/Panel")
local ProgressBar = require("../Components/ProgressBar")
local RegionPicker = require("../Components/RegionPicker")
local Slider = require("../Components/Slider")
local Stickers = require(ReplicatedStorage.Shared.Data.Stickers)
local StyleConsts = require("../Style/StyleConsts")
local TileGrid = require("../Components/TileGrid")
local ToolFrame = require("../Components/ToolFrame")

export type StickerPatternToolUI = {
	-- vars
	stickerData: Stickers.Stickers,
	stickerTool: any,
	stickerCounter: ProgressBar.ProgressBar,
	panel: Panel.Panel,
	maid: Maid.Maid,
	-- methods
	updateProgress: (self: StickerPatternToolUI) -> (),
	open: (self: StickerPatternToolUI) -> (),
	close: (self: StickerPatternToolUI) -> (),
	destroy: (self: StickerPatternToolUI) -> (),
}

--[=[
	@class StickerPatternToolUI
	@client

	The pattern panel: a grid of stickers to tile across the creation, a padding slider, and — on
	the body, where regional patterning is allowed — a region selector. Whichever of those two
	tools is absent leaves the other sticky at the top of the panel. Owned by [EditingUI].
]=]
local function StickerPatternToolUI(
	_creationInput: any,
	onClosePanelCallback: () -> (),
	onDeleteCallback: () -> (),
	onRegionSelectedCallback: (string) -> (),
	onSliderChangedCallback: (number, boolean) -> (),
	defaultSliderVal: number,
	regionParts: { string }?,
	stickerData: Stickers.Stickers,
	stickerTool: any
): StickerPatternToolUI
	local maid = Maid.new()
	local object = {} :: StickerPatternToolUI

	object.stickerData = stickerData
	object.stickerTool = stickerTool
	object.maid = maid

	object.stickerCounter = maid:add(ProgressBar(CreationStrings.counters.sticker, CreationConfig.maxStickerLayers))

	local componentsList = { object.stickerCounter.frame }

	local scrollingFrame = Create("ScrollingFrame", {
		Tags = { StyleConsts.tags.ScrollFrame },
	})

	local slider = maid:add(Slider(defaultSliderVal, onSliderChangedCallback))
	local sliderTool = ToolFrame(slider.frame, "Padding")

	if regionParts then
		local modelDisplayName = StyleConsts.modelDisplayName[regionParts[1]]

		local regionPillbar = RegionPicker(regionParts, onRegionSelectedCallback)
		local regionSelectTool = ToolFrame(regionPillbar, `{modelDisplayName} Section`)
		table.insert(componentsList, regionSelectTool)

		sliderTool.Parent = scrollingFrame
	else
		table.insert(componentsList, sliderTool)
	end

	local tileInfos = {}

	for _, sticker in object.stickerData do
		local info = {
			iconId = sticker.textureId,
			callback = function()
				object.stickerTool:applySticker(sticker.textureId)
				object:updateProgress()
				object.stickerTool:setPatterned(true)
			end,
		}
		table.insert(tileInfos, info)
	end

	local grid = TileGrid(tileInfos)
	grid.Name = "StickerGrid"

	local gridTool = ToolFrame(grid, "Pattern")
	gridTool.Parent = scrollingFrame

	table.insert(componentsList, scrollingFrame)

	object.panel = maid:add(Panel("Pattern", onClosePanelCallback, onDeleteCallback, componentsList))
	object.panel.frame.Name = "PatternStickerToolPanel"
	object.panel.frame.Visible = false

	--[=[
		@within StickerPatternToolUI

		Re-reads the tool's sticker count and moves the counter to match.
	]=]
	function object:updateProgress()
		self.stickerCounter:updateProgress(self.stickerTool.stickerCounter)
	end

	--[=[
		@within StickerPatternToolUI
	]=]
	function object:open()
		self.panel.frame.Visible = true
		self:updateProgress()
	end

	--[=[
		@within StickerPatternToolUI
	]=]
	function object:close()
		self.panel.frame.Visible = false
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return StickerPatternToolUI

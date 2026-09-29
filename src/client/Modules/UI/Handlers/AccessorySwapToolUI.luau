local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessoryCatalogs = require(ReplicatedStorage.Shared.Data.AccessoryCatalogs)
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Panel = require("../Components/Panel")
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")
local TileGrid = require("../Components/TileGrid")
local ToolFrame = require("../Components/ToolFrame")

export type AccessorySwapToolUI = {
	-- vars
	panel: Panel.Panel,
	maid: Maid.Maid,
	-- methods
	open: (self: AccessorySwapToolUI) -> (),
	close: (self: AccessorySwapToolUI) -> (),
	destroy: (self: AccessorySwapToolUI) -> (),
}

--[=[
	@class AccessorySwapToolUI
	@client

	The accessories panel: one thumbnail grid per slot, with the merged option outlined. An optional
	slot leads with a "none" tile. Owned by [EditingUI].
]=]
local function AccessorySwapToolUI(
	onClosePanelCallback: () -> (),
	onDeleteCallback: () -> (),
	catalog: AccessoryCatalogs.AccessoryCatalog,
	getSelections: () -> { [string]: number },
	onOptionSelected: (slotName: string, optionIndex: number) -> boolean
): AccessorySwapToolUI
	local maid = Maid.new()
	local object = {} :: AccessorySwapToolUI

	object.maid = maid

	local scrollingFrame = Create("ScrollingFrame", {
		Tags = { StyleConsts.tags.ScrollFrame },
	})

	for slotIndex, slot in catalog.slots do
		local firstIndex = if slot.optional then 0 else 1
		local tiles: { [number]: GuiObject } = {}

		local function highlight(selectedIndex: number)
			for optionIndex, tile in tiles do
				if optionIndex == selectedIndex then
					StyleUtils.addStyleTag(tile, StyleConsts.tags.MiniBaseTileSelected)
				else
					StyleUtils.removeStyleTag(tile, StyleConsts.tags.MiniBaseTileSelected)
				end
			end
		end

		local tileInfos = {}
		for optionIndex = firstIndex, #slot.options do
			local option = slot.options[optionIndex]
			table.insert(tileInfos, {
				iconId = if option then option.thumbnail else CreationIcons.icons.XButton,
				callback = function()
					if onOptionSelected(slot.name, optionIndex) then
						highlight(optionIndex)
					end
				end,
			})
		end

		local grid = TileGrid(tileInfos)
		grid.Name = `{slot.name}Grid`
		for _, tile in grid:GetChildren() do
			if tile:IsA("GuiObject") then
				tiles[tile.LayoutOrder - 1 + firstIndex] = tile
			end
		end
		highlight(getSelections()[slot.name] or firstIndex)

		local slotTool = ToolFrame(grid, slot.name)
		slotTool.LayoutOrder = slotIndex
		slotTool.Parent = scrollingFrame
	end

	object.panel = maid:add(Panel("Accessories", onClosePanelCallback, onDeleteCallback, { scrollingFrame }))
	object.panel.frame.Name = "AccessorySwapToolPanel"
	object.panel.frame.Visible = false

	--[=[
		@within AccessorySwapToolUI
	]=]
	function object:open()
		self.panel.frame.Visible = true
	end

	--[=[
		@within AccessorySwapToolUI
	]=]
	function object:close()
		self.panel.frame.Visible = false
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return AccessorySwapToolUI

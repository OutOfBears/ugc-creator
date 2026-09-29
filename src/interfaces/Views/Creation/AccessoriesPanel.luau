local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local React = require(ReplicatedStorage.Packages.React)

local Panel = require("../../Components/Panel")
local ScrollFrame = require("../../Components/ScrollFrame")
local TileGrid = require("../../Components/TileGrid")
local ToolFrame = require("../../Components/ToolFrame")
local useAtom = require("../../Hooks/useAtom")
local useCreationSession = require("../../Hooks/useCreationSession")

local createElement = React.createElement

export type AccessoriesPanelProps = {
	visible: boolean,
	onClose: () -> (),
}

--[=[
	@class AccessoriesPanel
	@client

	The accessories panel: one thumbnail grid per slot with the merged option outlined, driving
	[AccessorySwapTool]. An optional slot leads with a "none" tile.
]=]
local function AccessoriesPanel(props: AccessoriesPanelProps)
	local session = useCreationSession()
	local accessorySwapTool = session.accessorySwapTool
	local catalog = session.modelInfo:getAccessoryCatalog()
	local selections = useAtom(accessorySwapTool.selections)

	local slotTools = {}
	for slotIndex, slot in catalog.slots do
		local firstIndex = if slot.optional then 0 else 1
		local selectedIndex = selections[slot.name] or firstIndex

		local tiles = {}
		for optionIndex = firstIndex, #slot.options do
			local option = slot.options[optionIndex]
			table.insert(tiles, {
				icon = if option then option.thumbnail else CreationIcons.icons.XButton,
				selected = optionIndex == selectedIndex,
				onActivated = function()
					accessorySwapTool:selectOption(slot.name, optionIndex)
				end,
			})
		end

		slotTools[slot.name] = createElement(ToolFrame, {
			layoutOrder = slotIndex,
			title = slot.name,
		}, {
			grid = createElement(TileGrid, {
				tiles = tiles,
			}),
		})
	end

	return createElement(Panel, {
		title = CreationStrings.panelTitles.accessories,
		visible = props.visible,
		onClose = props.onClose,
		onTrash = function() end,
	}, {
		scrollFrame = createElement(ScrollFrame, {
			layoutOrder = 1,
		}, slotTools),
	})
end

return AccessoriesPanel

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorLayers = require(ReplicatedStorage.Shared.Data.ColorLayers)
local ColorPicker = require("../Components/ColorPicker")
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Panel = require("../Components/Panel")
local SegmentedControl = require("../Components/SegmentedControl")
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")
local ToolFrame = require("../Components/ToolFrame")

export type LayerColorToolUI = {
	-- vars
	panel: Panel.Panel,
	maid: Maid.Maid,
	-- methods
	open: (self: LayerColorToolUI) -> (),
	close: (self: LayerColorToolUI) -> (),
	destroy: (self: LayerColorToolUI) -> (),
}

--[=[
	@class LayerColorToolUI
	@client

	The layer recolor panel: a color picker that edits the selected section, a scrollable list of the
	creation's sections, and one segmented control per variant group (e.g. the mouth). Owned by
	[EditingUI].
]=]
local function LayerColorToolUI(
	onClosePanelCallback: () -> (),
	onDeleteCallback: () -> (),
	catalog: ColorLayers.Catalog,
	onSectionColorChanged: (sectionName: string, color: Color3, opacity: number, isFinalInput: boolean) -> (),
	onVariantSelected: (groupName: string, optionIndex: number) -> ()
): LayerColorToolUI
	local maid = Maid.new()
	local object = {} :: LayerColorToolUI

	object.maid = maid

	local sectionNames: { string } = {}
	for _, layer in catalog.layers do
		table.insert(sectionNames, layer.name)
	end
	for _, group in catalog.variantGroups do
		table.insert(sectionNames, group.name)
	end

	local activeSection = sectionNames[1]

	local scrollingFrame = Create("ScrollingFrame", {
		Tags = { StyleConsts.tags.ScrollFrame },
	})

	local colorPicker: ColorPicker.ColorPicker
	colorPicker = maid:add(ColorPicker(function(color: Color3, isFinalInput: boolean)
		onSectionColorChanged(activeSection, color, colorPicker:getOpacity(), isFinalInput)
	end, function(opacity: number)
		onSectionColorChanged(activeSection, colorPicker:getColor(), opacity, true)
	end))

	local colorPickerTool = ToolFrame(colorPicker.frame, "Color")
	colorPickerTool.Parent = scrollingFrame
	colorPickerTool.LayoutOrder = 1

	local sectionListFrame = Create("Frame", {
		Name = "SectionList",
		Tags = { StyleConsts.tags.SelectableList },
	})

	local sectionButtons: { [string]: TextButton } = {}
	local function selectSection(name: string)
		if sectionButtons[activeSection] then
			StyleUtils.removeStyleTag(sectionButtons[activeSection], StyleConsts.tags.ButtonSelected)
		end
		activeSection = name
		StyleUtils.addStyleTag(sectionButtons[name], StyleConsts.tags.ButtonSelected)
	end

	for index, name in sectionNames do
		local button = Create("TextButton", {
			Name = name,
			Text = "",
			LayoutOrder = index,
			Tags = { StyleConsts.tags.SelectableRow },
			Children = {
				Create("TextLabel", {
					Text = name,
					Tags = { StyleConsts.tags.SelectableRowLabel },
				}),
			},
			Parent = sectionListFrame,
		}) :: TextButton
		button.Activated:Connect(function()
			selectSection(name)
		end)
		sectionButtons[name] = button
	end
	if activeSection then
		StyleUtils.addStyleTag(sectionButtons[activeSection], StyleConsts.tags.ButtonSelected)
	end

	local sectionListTool = ToolFrame(sectionListFrame, "Sections")
	sectionListTool.Parent = scrollingFrame
	sectionListTool.LayoutOrder = 2

	for groupIndex, group in catalog.variantGroups do
		local buttonInfos = {}
		for optionIndex, groupOption in group.options do
			table.insert(buttonInfos, {
				text = groupOption.name,
				callback = function()
					onVariantSelected(group.name, optionIndex)
				end,
			})
		end

		local segmented = maid:add(SegmentedControl(buttonInfos))
		StyleUtils.addStyleTag(segmented.frame, StyleConsts.tags.SegmentedControlFill)

		local groupTool = ToolFrame(segmented.frame, group.name)
		groupTool.Parent = scrollingFrame
		groupTool.LayoutOrder = 2 + groupIndex
	end

	object.panel = maid:add(Panel("Colors", onClosePanelCallback, onDeleteCallback, { scrollingFrame }))
	object.panel.frame.Name = "LayerColorToolPanel"
	object.panel.frame.Visible = false

	--[=[
		@within LayerColorToolUI
	]=]
	function object:open()
		self.panel.frame.Visible = true
	end

	--[=[
		@within LayerColorToolUI
	]=]
	function object:close()
		self.panel.frame.Visible = false
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return LayerColorToolUI

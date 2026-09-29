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

export type ColorGroup = {
	keyPrefix: string,
	catalog: ColorLayers.Catalog,
}

export type LayerColorToolUI = {
	-- vars
	panel: Panel.Panel,
	maid: Maid.Maid,
	-- methods
	refresh: (self: LayerColorToolUI) -> (),
	open: (self: LayerColorToolUI) -> (),
	close: (self: LayerColorToolUI) -> (),
	destroy: (self: LayerColorToolUI) -> (),
}

--[=[
	@class LayerColorToolUI
	@client

	The layer recolor panel: a color picker that edits the selected section, a scrollable list of the
	creation's sections (the head's, then each merged accessory's, prefixed with its slot), and one
	segmented control per variant group (e.g. the mouth). Owned by [EditingUI].
]=]
local function LayerColorToolUI(
	onClosePanelCallback: () -> (),
	onDeleteCallback: () -> (),
	getColorGroups: () -> { ColorGroup },
	onSectionColorChanged: (sectionKey: string, color: Color3, opacity: number, isFinalInput: boolean) -> (),
	onVariantSelected: (groupKey: string, optionIndex: number) -> ()
): LayerColorToolUI
	local maid = Maid.new()
	local sectionsMaid = maid:add(Maid.new())
	local object = {} :: LayerColorToolUI

	object.maid = maid

	local activeSection: string? = nil

	local scrollingFrame = Create("ScrollingFrame", {
		Tags = { StyleConsts.tags.ScrollFrame },
	})

	local colorPicker: ColorPicker.ColorPicker
	colorPicker = maid:add(ColorPicker(function(color: Color3, isFinalInput: boolean)
		if activeSection then
			onSectionColorChanged(activeSection, color, colorPicker:getOpacity(), isFinalInput)
		end
	end, function(opacity: number)
		if activeSection then
			onSectionColorChanged(activeSection, colorPicker:getColor(), opacity, true)
		end
	end))

	local colorPickerTool = ToolFrame(colorPicker.frame, "Color")
	colorPickerTool.Parent = scrollingFrame
	colorPickerTool.LayoutOrder = 1

	local sectionButtons: { [string]: TextButton } = {}
	local function selectSection(key: string)
		if activeSection and sectionButtons[activeSection] then
			StyleUtils.removeStyleTag(sectionButtons[activeSection], StyleConsts.tags.ButtonSelected)
		end
		activeSection = key
		StyleUtils.addStyleTag(sectionButtons[key], StyleConsts.tags.ButtonSelected)
	end

	--[=[
		@within LayerColorToolUI

		Rebuilds the section list and variant controls from the current color groups, e.g. after an
		accessory swap. The selected section is kept when it still exists.
	]=]
	function object:refresh()
		sectionsMaid:doCleaning()
		table.clear(sectionButtons)

		local sectionListFrame = sectionsMaid:add(Create("Frame", {
			Name = "SectionList",
			Tags = { StyleConsts.tags.SelectableList },
		}))

		local keys: { string } = {}
		local variantGroups = {}
		for _, colorGroup in getColorGroups() do
			local catalog = colorGroup.catalog
			for _, layer in catalog.layers do
				table.insert(keys, colorGroup.keyPrefix .. layer.name)
			end
			for _, group in catalog.variantGroups do
				table.insert(keys, colorGroup.keyPrefix .. group.name)
				table.insert(variantGroups, { key = colorGroup.keyPrefix .. group.name, group = group })
			end
		end

		for index, key in keys do
			local button = Create("TextButton", {
				Name = key,
				Text = "",
				LayoutOrder = index,
				Tags = { StyleConsts.tags.SelectableRow },
				Children = {
					Create("TextLabel", {
						Text = (string.gsub(key, "%.", " · ")),
						Tags = { StyleConsts.tags.SelectableRowLabel },
					}),
				},
				Parent = sectionListFrame,
			}) :: TextButton
			button.Activated:Connect(function()
				selectSection(key)
			end)
			sectionButtons[key] = button
		end

		local keptSection = if activeSection and sectionButtons[activeSection] then activeSection else keys[1]
		activeSection = nil
		if keptSection then
			selectSection(keptSection)
		end

		local sectionListTool = sectionsMaid:add(ToolFrame(sectionListFrame, "Sections"))
		sectionListTool.Parent = scrollingFrame
		sectionListTool.LayoutOrder = 2

		for groupIndex, variantGroup in variantGroups do
			local buttonInfos = {}
			for optionIndex, groupOption in variantGroup.group.options do
				table.insert(buttonInfos, {
					text = groupOption.name,
					callback = function()
						onVariantSelected(variantGroup.key, optionIndex)
					end,
				})
			end

			local segmented = sectionsMaid:add(SegmentedControl(buttonInfos))
			StyleUtils.addStyleTag(segmented.frame, StyleConsts.tags.SegmentedControlFill)

			local label = string.gsub(variantGroup.key, "%.", " · ")
			local groupTool = sectionsMaid:add(ToolFrame(segmented.frame, label))
			groupTool.Parent = scrollingFrame
			groupTool.LayoutOrder = 2 + groupIndex
		end
	end

	object:refresh()

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

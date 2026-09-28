local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local IconButton = require("../Components/IconButton")
local LayersTool = require("../../Tools/LayersTool")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Panel = require("../Components/Panel")
local SegmentedControl = require("../Components/SegmentedControl")
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")
local TextureInfo = require(ReplicatedStorage.Shared.Modules.TextureInfo)
local ToolFrame = require("../Components/ToolFrame")

local DISABLED_TRANSPARENCY = 0.6

export type LayersToolUI = {
	-- vars
	panel: Panel.Panel,
	maid: Maid.Maid,
	-- methods
	refresh: (self: LayersToolUI) -> (),
	open: (self: LayersToolUI) -> (),
	close: (self: LayersToolUI) -> (),
	destroy: (self: LayersToolUI) -> (),
}

--[=[
	@class LayersToolUI
	@client

	The Layers panel: the layer stack listed top first, one row per layer with a visibility toggle,
	its name, move up/down and delete, plus an add button and the selected layer's blend mode.
	Owned by [EditingUI].
]=]
local function LayersToolUI(onClosePanelCallback: () -> (), layersTool: LayersTool.LayersTool): LayersToolUI
	local maid = Maid.new()
	local rowMaid = maid:add(Maid.new())
	local object = {} :: LayersToolUI

	object.maid = maid

	local function bindAction(button: GuiButton, enabled: boolean, onActivated: () -> ())
		button.Activated:Connect(function()
			if enabled then
				onActivated()
				object:refresh()
			end
		end)
	end

	local function createArrowButton(text: string, enabled: boolean, onActivated: () -> ()): TextButton
		local button = Create("TextButton", {
			Text = text,
			TextTransparency = if enabled then 0 else DISABLED_TRANSPARENCY,
			Tags = { StyleConsts.tags.LayerIconButton },
		}) :: TextButton
		bindAction(button, enabled, onActivated)

		return button
	end

	local scrollingFrame = Create("ScrollingFrame", {
		Tags = { StyleConsts.tags.ScrollFrame },
	})

	local layerList = Create("Frame", {
		Name = "SelectableList",
		Tags = { StyleConsts.tags.SelectableList },
	}) :: Frame

	local addButton = Create("TextButton", {
		Text = CreationStrings.addLayer,
		Tags = { StyleConsts.tags.LayerAddButton },
	}) :: TextButton
	maid:add(addButton.Activated:Connect(function()
		layersTool:addLayer()
		object:refresh()
	end))

	local layerListTool = ToolFrame(layerList, "", addButton)
	layerListTool.Parent = scrollingFrame
	layerListTool.LayoutOrder = 1
	local layerCountLabel = layerListTool:FindFirstChild("ToolTitleLabel", true) :: TextLabel

	local blendButtonInfos = {}
	for _, blendMode in CreationConfig.paintBlendModeOrder do
		table.insert(blendButtonInfos, {
			text = blendMode,
			callback = function()
				layersTool:setBlendMode(layersTool:getActiveLayerId(), blendMode)
			end,
		})
	end
	local blendControl = maid:add(SegmentedControl(blendButtonInfos))
	StyleUtils.addStyleTag(blendControl.frame, StyleConsts.tags.SegmentedControlFill)

	local blendTool = ToolFrame(blendControl.frame, CreationStrings.blendModeLabel)
	blendTool.Parent = scrollingFrame
	blendTool.LayoutOrder = 2

	local function createRow(paintLayer: TextureInfo.PaintLayer, index: number, layerCount: number): TextButton
		local layerId = paintLayer.id

		local row = Create("TextButton", {
			Name = layerId,
			Text = "",
			LayoutOrder = layerCount - index + 1,
			Tags = { StyleConsts.tags.SelectableRow },
		}) :: TextButton
		bindAction(row, true, function()
			layersTool:selectLayer(layerId)
		end)
		if layerId == layersTool:getActiveLayerId() then
			StyleUtils.addStyleTag(row, StyleConsts.tags.ButtonSelected)
		end

		local visibilityToggle = Create("ImageButton", {
			Name = "Visibility",
			LayoutOrder = 1,
			Image = if paintLayer.visible then CreationIcons.uiImages.ToggleOn else CreationIcons.uiImages.ToggleOff,
			Tags = { StyleConsts.tags.TogglePill },
			Parent = row,
		}) :: ImageButton
		bindAction(visibilityToggle, true, function()
			layersTool:setVisible(layerId, not paintLayer.visible)
		end)

		Create("TextLabel", {
			Name = "SelectableRowLabel",
			LayoutOrder = 2,
			Text = layersTool:getLayerName(layerId),
			TextTransparency = if paintLayer.visible then 0 else DISABLED_TRANSPARENCY,
			Tags = { StyleConsts.tags.SelectableRowLabel },
			Parent = row,
		})

		local upButton = createArrowButton(CreationStrings.layerMoveUp, index < layerCount, function()
			layersTool:moveLayer(layerId, 1)
		end)
		upButton.LayoutOrder = 3
		upButton.Parent = row

		local downButton = createArrowButton(CreationStrings.layerMoveDown, index > 1, function()
			layersTool:moveLayer(layerId, -1)
		end)
		downButton.LayoutOrder = 4
		downButton.Parent = row

		local canDelete = layersTool:canDeleteLayer()
		local deleteButton = IconButton(CreationIcons.icons.Delete)
		deleteButton.LayoutOrder = 5
		StyleUtils.addStyleTag(deleteButton, StyleConsts.tags.LayerIconButton)
		if not canDelete then
			(deleteButton:FindFirstChildWhichIsA("ImageLabel") :: ImageLabel).ImageTransparency = DISABLED_TRANSPARENCY
		end
		bindAction(deleteButton, canDelete, function()
			layersTool:deleteLayer(layerId)
		end)
		deleteButton.Parent = row

		return row
	end

	--[=[
		@within LayersToolUI

		Rebuilds the rows, the layer count and add button, and the blend mode selection from the
		current layer stack.
	]=]
	function object:refresh()
		rowMaid:doCleaning()

		local layers = layersTool:getLayers()
		for index, paintLayer in layers do
			local row = rowMaid:add(createRow(paintLayer, index, #layers))
			row.Parent = layerList
		end

		layerCountLabel.Text = string.format(CreationStrings.layerCountFormat, #layers, CreationConfig.maxPaintLayers)
		addButton.Visible = layersTool:canAddLayer()

		for _, paintLayer in layers do
			if paintLayer.id == layersTool:getActiveLayerId() then
				local blendIndex = table.find(CreationConfig.paintBlendModeOrder, paintLayer.blendMode)
				blendControl:applySelection(blendIndex or 1)
			end
		end
	end

	local function deleteActiveLayer()
		layersTool:deleteLayer(layersTool:getActiveLayerId())
		object:refresh()
	end

	object.panel =
		maid:add(Panel(CreationStrings.layersPanelTitle, onClosePanelCallback, deleteActiveLayer, { scrollingFrame }))
	object.panel.frame.Name = "LayersToolPanel"
	object.panel.frame.Visible = false

	--[=[
		@within LayersToolUI
	]=]
	function object:open()
		self:refresh()
		self.panel.frame.Visible = true
	end

	--[=[
		@within LayersToolUI
	]=]
	function object:close()
		self.panel.frame.Visible = false
	end

	function object:destroy()
		maid:doCleaning()
	end

	object:refresh()

	return object
end

return LayersToolUI

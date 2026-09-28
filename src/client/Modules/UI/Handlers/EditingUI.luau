local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessorySwapToolUI = require("./AccessorySwapToolUI")
local BrushToolUI = require("./BrushToolUI")
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local EraserToolUI = require("./EraserToolUI")
local FillToolUI = require("./FillToolUI")
local IconButton = require("../Components/IconButton")
local Kitbash = require(ReplicatedStorage.Shared.Data.Kitbash)
local KitbashToolUI = require("./KitbashToolUI")
local LayerColorToolUI = require("./LayerColorToolUI")
local LayersToolUI = require("./LayersToolUI")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StickerPatternToolUI = require("./StickerPatternToolUI")
local StickerToolUI = require("./StickerToolUI")
local Stickers = require(ReplicatedStorage.Shared.Data.Stickers)
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")
local Toolbar = require("../Components/Toolbar")
local UVCanvasUI = require("./UVCanvasUI")

local player = Players.LocalPlayer

export type EditingUI = {
	-- vars
	baseUI: any,
	session: any,
	creationInput: any,
	style: any,
	fabricTool: any,
	stickerTool: any,
	brushTool: any,
	kitbashTool: any,
	layerColorTool: any,
	layersTool: any,
	screenGui: ScreenGui,
	panelParent: Frame,
	toolbar: Toolbar.Toolbar,
	brushToolUI: BrushToolUI.BrushToolUI,
	eraserToolUI: EraserToolUI.EraserToolUI,
	fillToolUI: FillToolUI.FillToolUI?,
	stickerToolUI: StickerToolUI.StickerToolUI,
	stickerPatternToolUI: StickerPatternToolUI.StickerPatternToolUI,
	kitbashToolUI: KitbashToolUI.KitbashToolUI,
	layerColorToolUI: LayerColorToolUI.LayerColorToolUI?,
	accessorySwapToolUI: AccessorySwapToolUI.AccessorySwapToolUI?,
	layersToolUI: LayersToolUI.LayersToolUI,
	uvCanvasUI: UVCanvasUI.UVCanvasUI,
	canvasButtonGroup: Frame,
	isCanvasEnabled: boolean,
	maid: Maid.Maid,
	-- methods
	show: (self: EditingUI) -> (),
	hide: (self: EditingUI) -> (),
	destroy: (self: EditingUI) -> (),
}

--[=[
	@class EditingUI
	@client

	Every editing tool's panel plus the toolbar that opens them, covering both texture and mesh
	editing. Owned by [BaseUI].
]=]
local function EditingUI(
	baseUI: any,
	session: any,
	fabricTool: any,
	stickerTool: any,
	brushTool: any,
	kitbashTool: any,
	layerColorTool: any,
	layersTool: any
): EditingUI
	local maid = Maid.new()
	local object = {} :: EditingUI
	local playerGui = player:WaitForChild("PlayerGui")

	object.baseUI = baseUI
	object.session = session
	object.creationInput = session:getCreationInput()
	object.style = baseUI.style
	object.maid = maid

	object.fabricTool = fabricTool
	object.stickerTool = stickerTool
	object.brushTool = brushTool
	object.kitbashTool = kitbashTool
	object.layerColorTool = layerColorTool
	object.layersTool = layersTool

	local hasLayerCatalog = session.modelInfo:getLayerCatalog() ~= nil

	object.screenGui = maid:add(Create("ScreenGui", {
		Name = "EditingUI",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		Parent = playerGui,
	})) :: ScreenGui

	object.style:linkGui(object.screenGui)

	local frame = Create("Frame", {
		Name = "UIParent",
		Tags = { StyleConsts.tags.UIParent },
		Parent = object.screenGui,
	})

	local toolbarParent = Create("Frame", {
		Name = "ToolbarParent",
		Tags = { StyleConsts.tags.ToolbarParent },
		Parent = frame,
	})

	object.panelParent = Create("Frame", {
		Name = "PanelParent",
		Tags = { StyleConsts.tags.PanelParent },
		Parent = frame,
	}) :: Frame

	local canvasTarget: { panelFrame: Frame, mode: UVCanvasUI.UVCanvasMode }? = nil

	local function refreshCanvas()
		if not object.isCanvasEnabled or StyleUtils.getIsMobile(object.screenGui) then
			if object.uvCanvasUI:isOpen() then
				object.uvCanvasUI:close()
				if canvasTarget then
					object.session:panToLeft()
				else
					object.session:resetCamera()
				end
			end
			return
		end

		local target = canvasTarget
		if target then
			object.uvCanvasUI:open(target.mode, target.panelFrame)
		else
			object.uvCanvasUI:open("view", nil)
		end
	end

	local function attachCanvas(panelFrame: Frame, mode: UVCanvasUI.UVCanvasMode)
		canvasTarget = { panelFrame = panelFrame, mode = mode }
		refreshCanvas()
	end

	local function closeAndDisablePanels()
		canvasTarget = nil

		object.brushToolUI:close()
		object.eraserToolUI:close()
		object.brushTool:disable()

		object.stickerToolUI:close()
		object.stickerPatternToolUI:close()
		object.stickerTool:disable()

		object.kitbashToolUI:close()
		object.kitbashTool:disable()

		if object.fillToolUI then
			object.fillToolUI:close()
		end

		if object.layerColorToolUI then
			object.layerColorToolUI:close()
		end

		if object.accessorySwapToolUI then
			object.accessorySwapToolUI:close()
		end

		object.layersToolUI:close()

		object.session:hideMeshEditControls()
	end

	local function onOpenPanel()
		closeAndDisablePanels()
		object.baseUI:hideCoreUIBehindPanel()
	end

	local function onClosePanel()
		object.baseUI:unhideCoreUIBehindPanel()
		object.toolbar:removeSelection()
		object.session:resetCamera()
		closeAndDisablePanels()
		refreshCanvas()
	end

	local function createBrushToolUI()
		local minBrushSize = CreationConfig.minBrushSize
		local maxBrushSize = CreationConfig.maxBrushSize
		local defaultBrushSize = 10

		local defaultSliderVal = defaultBrushSize / (maxBrushSize - minBrushSize)

		local onDeleteCallback = function()
			object.brushTool:clearAll()
		end

		local onSliderChangedCallback = function(newValue, isFinalInput)
			local brushSize = newValue * (maxBrushSize - minBrushSize) + minBrushSize
			object.brushTool:onBrushSizeChanged(brushSize, isFinalInput)
		end

		local onColorChangedCallback = function(color, _isFinalInput)
			object.brushTool:onColorChanged(color)
		end
		local reflectiveModeCallback = function(isReflectiveMode)
			object.brushTool:setIsReflective(isReflectiveMode)
		end
		local transparencyPickerCallback = function(transparency)
			object.brushTool:setTransparency(transparency)
		end

		object.brushToolUI = maid:add(
			BrushToolUI(
				object.creationInput,
				onClosePanel,
				onDeleteCallback,
				defaultSliderVal,
				onSliderChangedCallback,
				onColorChangedCallback,
				reflectiveModeCallback,
				transparencyPickerCallback
			)
		)

		object.brushTool:onColorChanged(
			Color3.fromHSV(
				StyleConsts.defaultColorPickerColor.h,
				StyleConsts.defaultColorPickerColor.s,
				StyleConsts.defaultColorPickerColor.v
			)
		)

		object.brushToolUI.panel.frame.Parent = object.panelParent
	end

	local function createEraserToolUI()
		local minBrushSize = CreationConfig.minBrushSize
		local maxBrushSize = CreationConfig.maxBrushSize
		local defaultBrushSize = 5

		local defaultSliderVal = defaultBrushSize / (maxBrushSize - minBrushSize)

		local onDeleteCallback = function()
			object.brushTool:clearAll()
		end

		local onSliderChangedCallback = function(newValue, isFinalInput)
			local brushSize = newValue * (maxBrushSize - minBrushSize) + minBrushSize
			object.brushTool:onBrushSizeChanged(brushSize, isFinalInput)
		end

		object.eraserToolUI = maid:add(
			EraserToolUI(
				object.creationInput,
				onClosePanel,
				onDeleteCallback,
				defaultSliderVal,
				onSliderChangedCallback
			)
		)

		object.brushTool:onEraserSizeChanged(defaultBrushSize)

		object.eraserToolUI.panel.frame.Parent = object.panelParent
	end

	local function createFillToolUI()
		local selectedRegionCallback = function(selectedRegion)
			object.fabricTool:setSelectedRegion(selectedRegion)
		end
		local colorPickerCallback = function(color, isFinalInput)
			object.fabricTool:applyColor(color, isFinalInput)
		end
		local reflectiveModeCallback = function(isReflectiveMode)
			object.fabricTool:setIsReflective(isReflectiveMode)
			object.fabricTool:reapplyFillForReflectivity()
		end
		local opacityPickerCallback = function(opacity)
			object.fabricTool:setOpacity(opacity)
		end
		local deleteCallback = function()
			object.fabricTool:clearAll()
		end
		local regionParts = object.session.modelInfo:getRegionPartsList()

		object.fillToolUI = maid:add(
			FillToolUI(
				object.creationInput,
				onClosePanel,
				deleteCallback,
				regionParts,
				selectedRegionCallback,
				colorPickerCallback,
				reflectiveModeCallback,
				opacityPickerCallback
			)
		)
		object.fillToolUI.panel.frame.Parent = object.panelParent
	end

	local function createLayerColorToolUI()
		local modelInfo = object.session.modelInfo
		local catalog = modelInfo:getLayerCatalog()
		if not catalog then
			return
		end

		local getColorGroups = function()
			local colorGroups: { LayerColorToolUI.ColorGroup } = { { keyPrefix = "", catalog = catalog } }

			local accessoryCatalog = modelInfo:getAccessoryCatalog()
			if accessoryCatalog then
				for _, slot in accessoryCatalog.slots do
					local option = modelInfo:getSelectedAccessory(slot.name)
					if option then
						table.insert(colorGroups, { keyPrefix = `{slot.name}.`, catalog = option.colors })
					end
				end
			end

			return colorGroups
		end
		local sectionColorChanged = function(sectionName, color, opacity, isFinalInput)
			object.layerColorTool:applySectionColor(sectionName, color, opacity, isFinalInput)
		end
		local variantSelected = function(groupName, optionIndex)
			object.layerColorTool:selectVariant(groupName, optionIndex)
		end
		local deleteCallback = function() end

		object.layerColorToolUI = maid:add(
			LayerColorToolUI(onClosePanel, deleteCallback, getColorGroups, sectionColorChanged, variantSelected)
		)
		object.layerColorToolUI.panel.frame.Parent = object.panelParent
	end

	local function createAccessorySwapToolUI()
		local modelInfo = object.session.modelInfo
		local catalog = modelInfo:getAccessoryCatalog()
		local accessorySwapTool = object.session.accessorySwapTool
		if not catalog or not accessorySwapTool then
			return
		end

		local getSelections = function()
			return modelInfo:getAccessorySelections()
		end
		local optionSelected = function(slotName, optionIndex)
			local swapped = accessorySwapTool:selectOption(slotName, optionIndex)
			if swapped and object.layerColorToolUI then
				object.layerColorToolUI:refresh()
			end

			return swapped
		end
		local deleteCallback = function() end

		object.accessorySwapToolUI =
			maid:add(AccessorySwapToolUI(onClosePanel, deleteCallback, catalog, getSelections, optionSelected))
		object.accessorySwapToolUI.panel.frame.Parent = object.panelParent
	end

	local function createStickerToolUI()
		local deleteCallback = function()
			object.stickerTool:deleteCurrentSticker()
			object.stickerToolUI:updateProgress()
		end

		object.stickerToolUI = maid:add(StickerToolUI(onClosePanel, deleteCallback, Stickers, object.stickerTool))
		object.stickerToolUI.panel.frame.Parent = object.panelParent
	end

	local function createStickerPatternToolUI()
		local deleteCallback = function()
			object.stickerTool:deleteCurrentSticker()
			object.stickerPatternToolUI:updateProgress()
		end

		local regionParts = if object.session.modelInfo:getRegionalStickerPatterningEnabled()
			then object.session.modelInfo:getRegionPartsList()
			else nil
		local selectedRegionCallback = function(selectedRegion)
			object.stickerTool:setSelectedRegion(selectedRegion)
		end

		local minPadding = CreationConfig.minStickerPadding
		local maxPadding = CreationConfig.maxStickerPadding
		local defaultPadding = 0

		local sliderCallback = function(newValue, isFinalInput)
			local paddingValue = newValue * (maxPadding - minPadding) + minPadding
			object.stickerTool:onPatternPaddingChanged(paddingValue, isFinalInput)
		end

		object.stickerPatternToolUI = maid:add(
			StickerPatternToolUI(
				object.creationInput,
				onClosePanel,
				deleteCallback,
				selectedRegionCallback,
				sliderCallback,
				defaultPadding,
				regionParts,
				Stickers,
				object.stickerTool
			)
		)

		object.stickerPatternToolUI.panel.frame.Parent = object.panelParent
	end

	local function createKitbashToolUI()
		local deleteCallback = function()
			object.kitbashTool:deleteCurrentPiece()
			object.kitbashToolUI:updateProgress()
		end

		object.kitbashToolUI = maid:add(KitbashToolUI(onClosePanel, deleteCallback, Kitbash, object.kitbashTool))
		object.kitbashToolUI.panel.frame.Parent = object.panelParent
	end

	local function openWidgetControls(widgetControlName: string)
		closeAndDisablePanels()
		object.baseUI:unhideCoreUIBehindPanel()
		object.session:showMeshEditControls(widgetControlName)
		refreshCanvas()
	end

	local function getMeshEditingGroup()
		local widgetGroupNames = object.session:getWidgetGroupNames()

		if #widgetGroupNames == 0 then
			return nil
		end

		local group = {}
		for _, name in widgetGroupNames do
			local buttonInfo = {
				iconId = CreationIcons.widgetIcons[name],
				mutedIconId = CreationIcons.widgetIcons[name .. "Muted"],
				callback = function()
					openWidgetControls(name)
				end,
			}
			table.insert(group, buttonInfo)
		end

		return group
	end

	local function setupToolbar()
		local paintingGroup = {
			{
				iconId = CreationIcons.icons.Paintbrush,
				mutedIconId = CreationIcons.icons.PaintbrushMuted,
				callback = function()
					onOpenPanel()
					object.brushTool:setStatePainting()
					object.brushToolUI:open()
					object.brushTool:enable()
					object.session:panToLeft()
					attachCanvas(object.brushToolUI.panel.frame, "paint")
				end,
			},
			{
				iconId = CreationIcons.icons.Eraser,
				mutedIconId = CreationIcons.icons.EraserMuted,
				callback = function()
					onOpenPanel()
					object.brushTool:setStateErasing()
					object.eraserToolUI:open()
					object.brushTool:enable()
					object.session:panToLeft()
					attachCanvas(object.eraserToolUI.panel.frame, "paint")
				end,
			},
		}

		local fillGroup = {
			{
				iconId = CreationIcons.icons.Recolor,
				callback = function()
					onOpenPanel()
					object.fillToolUI:open()
					object.session:panToLeft()
					attachCanvas(object.fillToolUI.panel.frame, "view")
				end,
			},
		}

		local layerColorGroup = {
			{
				iconId = CreationIcons.icons.Recolor,
				callback = function()
					onOpenPanel()
					object.layerColorToolUI:open()
					object.session:panToLeft()
					attachCanvas(object.layerColorToolUI.panel.frame, "view")
				end,
			},
		}

		local layersGroup = {
			{
				iconId = CreationIcons.icons.Layers,
				callback = function()
					onOpenPanel()
					object.brushTool:setStatePainting()
					object.layersToolUI:open()
					object.brushTool:enable()
					object.session:panToLeft()
					attachCanvas(object.layersToolUI.panel.frame, "paint")
				end,
			},
		}

		local stickerGroup = {
			{
				iconId = CreationIcons.icons.Decal,
				mutedIconId = CreationIcons.icons.DecalMuted,
				callback = function()
					onOpenPanel()
					object.stickerTool:enable()
					object.stickerToolUI:open()
					object.session:panToLeft()
					attachCanvas(object.stickerToolUI.panel.frame, "sticker")
				end,
			},
		}
		if object.session.modelInfo:getStickerPatterningEnabled() then
			local patternsButton = {
				iconId = CreationIcons.icons.Pattern,
				mutedIconId = CreationIcons.icons.PatternMuted,
				callback = function()
					onOpenPanel()
					object.stickerPatternToolUI:open()
					object.stickerTool:enable()
					attachCanvas(object.stickerPatternToolUI.panel.frame, "view")
				end,
			}
			table.insert(stickerGroup, patternsButton)
		end

		local kitbashGroup = {
			{
				iconId = CreationIcons.icons.Kitbashing,
				callback = function()
					onOpenPanel()
					object.kitbashToolUI:open()
					object.kitbashTool:enable()
					object.session:panToLeft()
					attachCanvas(object.kitbashToolUI.panel.frame, "view")
				end,
			},
		}

		local accessoryGroup = {
			{
				iconId = CreationIcons.icons.Accessories,
				callback = function()
					onOpenPanel()
					object.accessorySwapToolUI:open()
					object.session:panToLeft()
					attachCanvas(object.accessorySwapToolUI.panel.frame, "view")
				end,
			},
		}

		local toolbarGroups = {
			paintingGroup,
			if hasLayerCatalog then layerColorGroup else fillGroup,
			stickerGroup,
			layersGroup,
		}

		if object.accessorySwapToolUI then
			table.insert(toolbarGroups, accessoryGroup)
		end

		if object.session.modelInfo:getKitbashingEnabled() then
			table.insert(toolbarGroups, kitbashGroup)
		end

		if object.session.modelInfo:getWidgetMeshEditingEnabled() then
			local meshWidgetGroup = getMeshEditingGroup()
			table.insert(toolbarGroups, meshWidgetGroup)
		end

		object.toolbar = maid:add(Toolbar(toolbarGroups, onClosePanel))
	end

	local function setupCanvasToolbarButton()
		local buttonGroup = Create("Frame", {
			Name = "UVCanvasButtonGroup",
			LayoutOrder = #object.toolbar.buttonGroups + 1,
			Tags = { StyleConsts.tags.ToolbarButtonGroup },
			Parent = object.toolbar:getFrame(),
		}) :: Frame

		local canvasButton = IconButton(CreationIcons.icons.UVCanvas, function()
			object.isCanvasEnabled = not object.isCanvasEnabled

			if object.isCanvasEnabled then
				StyleUtils.addStyleTag(buttonGroup, StyleConsts.tags.ButtonSelected)
			else
				StyleUtils.removeStyleTag(buttonGroup, StyleConsts.tags.ButtonSelected)
			end

			refreshCanvas()
		end)
		StyleUtils.addStyleTag(canvasButton, StyleConsts.tags.ToolbarButton)
		canvasButton.Parent = buttonGroup

		local function refreshVisibility()
			buttonGroup.Visible = not StyleUtils.getIsMobile(object.screenGui)
		end

		maid:add(object.screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshVisibility))
		refreshVisibility()

		object.canvasButtonGroup = buttonGroup
	end

	object.isCanvasEnabled = false
	object.uvCanvasUI =
		maid:add(UVCanvasUI(session, session.modelInfo, object.creationInput, object.brushTool, object.stickerTool))
	object.uvCanvasUI.container.Parent = object.screenGui

	createBrushToolUI()
	createEraserToolUI()
	if hasLayerCatalog then
		createLayerColorToolUI()
	else
		createFillToolUI()
	end
	createStickerToolUI()
	createStickerPatternToolUI()
	createKitbashToolUI()
	createAccessorySwapToolUI()
	object.layersToolUI = maid:add(LayersToolUI(onClosePanel, object.layersTool))
	object.layersToolUI.panel.frame.Parent = object.panelParent

	setupToolbar()
	setupCanvasToolbarButton()
	object.toolbar:getFrame().Parent = toolbarParent

	--[=[
		@within EditingUI

		Closes every panel and hides the toolbar, leaving the model unobstructed.
	]=]
	function object:hide()
		closeAndDisablePanels()
		self.uvCanvasUI:close()
		self.baseUI:unhideCoreUIBehindPanel()
		self.toolbar:removeSelection()
		self.screenGui.Enabled = false
	end

	--[=[
		@within EditingUI
	]=]
	function object:show()
		self.screenGui.Enabled = true
		refreshCanvas()
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return EditingUI

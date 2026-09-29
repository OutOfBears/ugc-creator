local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessoriesPanel = require(ReplicatedStorage.Interfaces.Views.Creation.AccessoriesPanel)
local BrushPanel = require(ReplicatedStorage.Interfaces.Views.Creation.BrushPanel)
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local EraserPanel = require(ReplicatedStorage.Interfaces.Views.Creation.EraserPanel)
local FillPanel = require(ReplicatedStorage.Interfaces.Views.Creation.FillPanel)
local IconButton = require("../Components/IconButton")
local KitbashPanel = require(ReplicatedStorage.Interfaces.Views.Creation.KitbashPanel)
local LayerColorPanel = require(ReplicatedStorage.Interfaces.Views.Creation.LayerColorPanel)
local LayersPanel = require(ReplicatedStorage.Interfaces.Views.Creation.LayersPanel)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local PatternPanel = require(ReplicatedStorage.Interfaces.Views.Creation.PatternPanel)
local ReactPanelHost = require("./ReactPanelHost")
local StickersPanel = require(ReplicatedStorage.Interfaces.Views.Creation.StickersPanel)
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
	brushToolUI: ReactPanelHost.ReactPanelHost,
	eraserToolUI: ReactPanelHost.ReactPanelHost,
	fillToolUI: ReactPanelHost.ReactPanelHost?,
	stickerToolUI: ReactPanelHost.ReactPanelHost,
	stickerPatternToolUI: ReactPanelHost.ReactPanelHost,
	kitbashToolUI: ReactPanelHost.ReactPanelHost,
	layerColorToolUI: ReactPanelHost.ReactPanelHost?,
	accessorySwapToolUI: ReactPanelHost.ReactPanelHost?,
	layersToolUI: ReactPanelHost.ReactPanelHost,
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
		object.brushToolUI = maid:add(ReactPanelHost(object, BrushPanel, onClosePanel))

		object.brushTool:onColorChanged(
			Color3.fromHSV(
				CreationConfig.defaultColorPickerColor.h,
				CreationConfig.defaultColorPickerColor.s,
				CreationConfig.defaultColorPickerColor.v
			)
		)
	end

	local function createEraserToolUI()
		object.eraserToolUI = maid:add(ReactPanelHost(object, EraserPanel, onClosePanel))

		object.brushTool:onEraserSizeChanged(CreationConfig.defaultEraserSize)
	end

	local function createFillToolUI()
		object.fillToolUI = maid:add(ReactPanelHost(object, FillPanel, onClosePanel))
	end

	local function createLayerColorToolUI()
		object.layerColorToolUI = maid:add(ReactPanelHost(object, LayerColorPanel, onClosePanel))
	end

	local function createAccessorySwapToolUI()
		if not object.session.modelInfo:getAccessoryCatalog() or not object.session.accessorySwapTool then
			return
		end

		object.accessorySwapToolUI = maid:add(ReactPanelHost(object, AccessoriesPanel, onClosePanel))
	end

	local function createStickerToolUI()
		object.stickerToolUI = maid:add(ReactPanelHost(object, StickersPanel, onClosePanel))
	end

	local function createStickerPatternToolUI()
		object.stickerPatternToolUI = maid:add(ReactPanelHost(object, PatternPanel, onClosePanel))
	end

	local function createKitbashToolUI()
		object.kitbashToolUI = maid:add(ReactPanelHost(object, KitbashPanel, onClosePanel))
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
	object.layersToolUI = maid:add(ReactPanelHost(object, LayersPanel, onClosePanel))

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

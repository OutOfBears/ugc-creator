local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local ClientAtoms = require("./ClientAtoms")
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local UVCanvas = require("./UVCanvas")

export type Tool = {
	id: string,
	icon: string,
	mutedIcon: string?,
	panel: string?,
	canvasMode: UVCanvas.UVCanvasMode?,
	pansCamera: boolean?,
	activate: (() -> ())?,
	widgetGroup: string?,
}

export type CreationPanels = {
	-- vars
	session: any,
	activeTool: Charm.Atom<string?>,
	canvasEnabled: Charm.Atom<boolean>,
	toolbarGroups: { { Tool } },
	canvas: UVCanvas.UVCanvas,
	maid: Maid.Maid,
	-- methods
	activate: (self: CreationPanels, toolId: string) -> (),
	closePanel: (self: CreationPanels) -> (),
	toggleCanvas: (self: CreationPanels) -> (),
	isPanelOpen: (self: CreationPanels, activeToolId: string?) -> boolean,
	setPanelFrame: (self: CreationPanels, panel: string, frame: Frame?) -> (),
	hide: (self: CreationPanels) -> (),
	show: (self: CreationPanels) -> (),
	destroy: (self: CreationPanels) -> (),
}

--[=[
	@class CreationPanels
	@client

	Opens and closes the editor's tools. Owns which tool is active, the toolbar's grouping, whether
	the 2D canvas is on, and the sequencing each tool needs on open — disabling the other tools,
	enabling its own, panning the camera and anchoring the canvas beside its panel. The React
	toolbar and panels only read its atoms and call its methods.

	Owned by [CreationSession].
]=]
local function CreationPanels(session: any): CreationPanels
	local maid = Maid.new()
	local object = {} :: CreationPanels

	local modelInfo = session.modelInfo
	local brushTool = session.brushTool
	local stickerTool = session.stickerTool
	local kitbashTool = session.kitbashTool

	object.session = session
	object.activeTool = Charm.atom(nil :: string?)
	object.canvasEnabled = Charm.atom(false)
	object.maid = maid

	local toolsById: { [string]: Tool } = {}
	local panelFrames: { [string]: Frame? } = {}
	local canvasTarget: { panel: string, mode: UVCanvas.UVCanvasMode }? = nil

	local function closeCanvas()
		object:toggleCanvas()
	end

	object.canvas = maid:add(UVCanvas(modelInfo, session:getCreationInput(), brushTool, stickerTool, closeCanvas))

	local function refreshCanvas()
		local canvas = object.canvas

		if not object.canvasEnabled() or ClientAtoms.isMobile() then
			canvas:close()
			return
		end

		local target = canvasTarget
		if target then
			canvas:open(target.mode, panelFrames[target.panel])
		else
			canvas:open("view", nil)
		end
	end

	local function closeAndDisableTools()
		canvasTarget = nil

		brushTool:disable()
		stickerTool:disable()
		kitbashTool:disable()

		session:hideMeshEditControls()
	end

	local function tool(definition: Tool): Tool
		toolsById[definition.id] = definition

		return definition
	end

	local function panelTool(
		id: string,
		icon: string,
		mutedIcon: string?,
		canvasMode: UVCanvas.UVCanvasMode,
		pansCamera: boolean,
		activate: (() -> ())?
	): Tool
		return tool({
			id = id,
			icon = icon,
			mutedIcon = mutedIcon,
			panel = id,
			canvasMode = canvasMode,
			pansCamera = pansCamera,
			activate = activate,
		})
	end

	local icons = CreationIcons.icons

	local groups: { { Tool } } = {
		{
			panelTool("brush", icons.Paintbrush, icons.PaintbrushMuted, "paint", true, function()
				brushTool:setStatePainting()
				brushTool:enable()
			end),
			panelTool("eraser", icons.Eraser, icons.EraserMuted, "paint", true, function()
				brushTool:setStateErasing()
				brushTool:enable()
			end),
		},
		if modelInfo:getLayerCatalog()
			then { panelTool("layerColor", icons.Recolor, nil, "view", true) }
			else { panelTool("fill", icons.Recolor, nil, "view", true) },
	}

	local stickerGroup = {
		panelTool("sticker", icons.Decal, icons.DecalMuted, "sticker", true, function()
			stickerTool:enable()
		end),
	}
	if modelInfo:getStickerPatterningEnabled() then
		table.insert(
			stickerGroup,
			panelTool("pattern", icons.Pattern, icons.PatternMuted, "view", false, function()
				stickerTool:enable()
			end)
		)
	end
	table.insert(groups, stickerGroup)

	table.insert(groups, {
		panelTool("layers", icons.Layers, nil, "paint", true, function()
			brushTool:setStatePainting()
			brushTool:enable()
		end),
	})

	if modelInfo:getAccessoryCatalog() and session.accessorySwapTool then
		table.insert(groups, { panelTool("accessories", icons.Accessories, nil, "view", true) })
	end

	if modelInfo:getKitbashingEnabled() then
		table.insert(groups, {
			panelTool("kitbash", icons.Kitbashing, nil, "view", true, function()
				kitbashTool:enable()
			end),
		})
	end

	if modelInfo:getWidgetMeshEditingEnabled() then
		local widgetGroup = {}
		for _, name in session:getWidgetGroupNames() do
			table.insert(
				widgetGroup,
				tool({
					id = `widget:{name}`,
					icon = CreationIcons.widgetIcons[name],
					mutedIcon = CreationIcons.widgetIcons[name .. "Muted"],
					widgetGroup = name,
				})
			)
		end

		if #widgetGroup > 0 then
			table.insert(groups, widgetGroup)
		end
	end

	object.toolbarGroups = groups

	--[=[
		@within CreationPanels
		@param toolId string -- a tool from `toolbarGroups`

		Switches to a tool: every other tool is disabled, then this one's panel opens (or its mesh
		widgets show), the camera pans clear of the panel and the canvas moves beside it.
	]=]
	function object:activate(toolId: string)
		local definition = toolsById[toolId]
		if not definition then
			return
		end

		closeAndDisableTools()
		self.activeTool(toolId)

		if definition.widgetGroup then
			session:showMeshEditControls(definition.widgetGroup)
			refreshCanvas()
			return
		end

		if definition.activate then
			definition.activate()
		end

		if definition.pansCamera then
			session:panToLeft()
		end

		canvasTarget = { panel = definition.panel :: string, mode = definition.canvasMode :: UVCanvas.UVCanvasMode }
		refreshCanvas()
	end

	--[=[
		@within CreationPanels

		Closes the open panel or mesh widgets and returns the camera to its resting framing.
	]=]
	function object:closePanel()
		self.activeTool(nil)
		session:resetCamera()
		closeAndDisableTools()
		refreshCanvas()
	end

	--[=[
		@within CreationPanels
	]=]
	function object:toggleCanvas()
		self.canvasEnabled(not self.canvasEnabled())
		refreshCanvas()
	end

	--[=[
		@within CreationPanels
		@param activeToolId string? -- a value of `activeTool`
		@return boolean -- true when that tool opens a panel, as opposed to mesh widgets or nothing
	]=]
	function object:isPanelOpen(activeToolId: string?): boolean
		local definition = activeToolId and toolsById[activeToolId]

		return definition ~= nil and definition.panel ~= nil
	end

	--[=[
		@within CreationPanels
		@param panel string -- the panel's tool id
		@param frame Frame? -- its rendered frame, or nil once unmounted

		Registers where a panel is on screen so the canvas can sit beside it.
	]=]
	function object:setPanelFrame(panel: string, frame: Frame?)
		panelFrames[panel] = frame
	end

	--[=[
		@within CreationPanels

		Closes every tool and the canvas, for leaving the editor view (e.g. for the avatar preview).
	]=]
	function object:hide()
		closeAndDisableTools()
		self.activeTool(nil)
		self.canvas:close()
	end

	--[=[
		@within CreationPanels
	]=]
	function object:show()
		refreshCanvas()
	end

	function object:destroy()
		maid:doCleaning()
	end

	brushTool:onColorChanged(
		Color3.fromHSV(
			CreationConfig.defaultColorPickerColor.h,
			CreationConfig.defaultColorPickerColor.s,
			CreationConfig.defaultColorPickerColor.v
		)
	)
	brushTool:onEraserSizeChanged(CreationConfig.defaultEraserSize)

	return object
end

return CreationPanels

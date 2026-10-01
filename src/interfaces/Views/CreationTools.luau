local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local React = require(ReplicatedStorage.Packages.React)

local AccessoriesPanel = require("./Creation/AccessoriesPanel")
local BrushPanel = require("./Creation/BrushPanel")
local EraserPanel = require("./Creation/EraserPanel")
local FillPanel = require("./Creation/FillPanel")
local KitbashPanel = require("./Creation/KitbashPanel")
local LayerColorPanel = require("./Creation/LayerColorPanel")
local LayersPanel = require("./Creation/LayersPanel")
local PatternPanel = require("./Creation/PatternPanel")
local SessionGate = require("./Creation/SessionGate")
local StickersPanel = require("./Creation/StickersPanel")
local Toolbar = require("../Components/Toolbar")
local useAtom = require("../Hooks/useAtom")
local useCreationSession = require("../Hooks/useCreationSession")
local useScreenGui = require("../Hooks/useScreenGui")
local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement

local PANEL_VIEWS = {
	brush = BrushPanel,
	eraser = EraserPanel,
	fill = FillPanel,
	layerColor = LayerColorPanel,
	sticker = StickersPanel,
	pattern = PatternPanel,
	layers = LayersPanel,
	accessories = AccessoriesPanel,
	kitbash = KitbashPanel,
}

export type CreationToolsProps = {
	playerGui: ScreenGui,
}

local function Tools(props: CreationToolsProps)
	local theme = useTheme()
	local layout = theme.layout

	local session = useCreationSession()
	local panels = session.panels
	local activeTool = useAtom(panels.activeTool)
	local canvasEnabled = useAtom(panels.canvasEnabled)
	local screen = useAtom(session.screen)

	useScreenGui(props.playerGui, {
		DisplayOrder = 5,
		Enabled = screen == "edit",
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
	})

	local groups = {}
	local panelViews = {}
	for groupIndex, tools in panels.toolbarGroups do
		local buttons = {}
		local activeButton = nil

		for buttonIndex, tool in tools do
			buttons[buttonIndex] = { icon = tool.icon, mutedIcon = tool.mutedIcon }
			if tool.id == activeTool then
				activeButton = buttonIndex
			end

			local panel = tool.panel
			if panel then
				panelViews[panel] = createElement(PANEL_VIEWS[panel], {
					visible = activeTool == tool.id,
					onClose = function()
						panels:closePanel()
					end,
					frameRef = function(frame: Frame?)
						panels:setPanelFrame(panel, frame)
					end,
				})
			end
		end

		table.insert(groups, {
			key = `group{groupIndex}`,
			buttons = buttons,
			selected = activeButton ~= nil,
			activeButton = activeButton,
			onPress = function(buttonIndex: number)
				local toolId = tools[buttonIndex].id
				if toolId == activeTool then
					panels:closePanel()
				else
					panels:activate(toolId)
				end
			end,
		})
	end

	table.insert(groups, {
		key = "canvas",
		buttons = { { icon = CreationIcons.icons.UVCanvas } },
		selected = canvasEnabled,
		visible = not theme.isMobile,
		onPress = function()
			panels:toggleCanvas()
		end,
	})

	return createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, {
		padding = createElement("UIPadding", {
			PaddingRight = layout.UIParentPaddingRight,
			PaddingTop = layout.UIParentPaddingTop,
		}),
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = theme.tokens.Padding.Small,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		toolbarParent = createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = layout.ToolbarLayoutOrder,
			Size = UDim2.fromScale(0, 1),
		}, {
			padding = createElement("UIPadding", {
				PaddingBottom = layout.ToolbarParentPaddingBottom,
			}),
			flexItem = createElement("UIFlexItem", {
				FlexMode = layout.ToolbarParentFlexFill,
			}),
			toolbar = createElement(Toolbar, {
				groups = groups,
			}),
		}),
		panelParent = createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = layout.PanelLayoutOrder,
			Size = UDim2.fromScale(0, 1),
		}, {
			flexItem = createElement("UIFlexItem", {
				FlexMode = layout.PanelParentFlexFill,
			}),
			panels = createElement(React.Fragment, nil, panelViews),
		}),
	})
end

--[=[
	@class CreationTools
	@client

	The editor's tool strip and the panel column beside it, over the whole screen. Which tool is
	active, and what opening one does, belongs to [CreationPanels]; this view renders it.
]=]
local function CreationTools(props: CreationToolsProps)
	return createElement(SessionGate, nil, {
		tools = createElement(Tools, props),
	})
end

return CreationTools

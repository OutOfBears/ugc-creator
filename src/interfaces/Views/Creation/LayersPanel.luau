local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local React = require(ReplicatedStorage.Packages.React)

local IconButton = require("../../Components/IconButton")
local Panel = require("../../Components/Panel")
local ScrollFrame = require("../../Components/ScrollFrame")
local SegmentedControl = require("../../Components/SegmentedControl")
local SelectableRow = require("../../Components/SelectableRow")
local ToolFrame = require("../../Components/ToolFrame")
local useAtom = require("../../Hooks/useAtom")
local useCreationSession = require("../../Hooks/useCreationSession")
local useTheme = require("../../Hooks/useTheme")

local createElement = React.createElement

export type LayersPanelProps = {
	visible: boolean,
	onClose: () -> (),
}

--[=[
	@class LayersPanel
	@client

	The Layers panel: the paint layer stack listed top first, one row per layer with a visibility
	toggle, its name, move up/down and delete, plus an add button and the selected layer's blend
	mode. Reads the stack from [LayersTool].`state`.
]=]
local function LayersPanel(props: LayersPanelProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local fonts = theme.fonts
	local layersTool = useCreationSession().layersTool
	local state = useAtom(layersTool.state)

	local layers = state.layers
	local layerCount = #layers
	local disabled = tokens.DisabledTransparency

	local function layerButton(layoutOrder: number, native: { [string]: any })
		native.BackgroundColor3 = tokens.Shift_300.Color3
		native.BackgroundTransparency = tokens.Shift_300.Transparency
		native.BorderSizePixel = 0
		native.LayoutOrder = layoutOrder
		native.Size = UDim2.fromOffset(32, 32)

		return native
	end

	local function arrowButton(text: string, layoutOrder: number, enabled: boolean, onActivated: () -> ())
		return createElement(
			"TextButton",
			layerButton(layoutOrder, {
				FontFace = fonts.ButtonFont.Font,
				Text = text,
				TextColor3 = tokens.Colors.ContentEmphasis,
				TextSize = fonts.ButtonFont.FontSize,
				TextTransparency = if enabled then 0 else disabled,
				[React.Event.Activated] = function()
					if enabled then
						onActivated()
					end
				end,
			}),
			{
				corner = createElement("UICorner", {
					CornerRadius = tokens.Radius.Small,
				}),
			}
		)
	end

	local rows = {}
	for index, layer in layers do
		local layerId = layer.id

		rows[layerId] = createElement(SelectableRow, {
			layoutOrder = layerCount - index + 1,
			selected = layerId == state.activeLayerId,
			onActivated = function()
				layersTool:selectLayer(layerId)
			end,
		}, {
			visibility = createElement("ImageButton", {
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = if layer.visible then CreationIcons.uiImages.ToggleOn else CreationIcons.uiImages.ToggleOff,
				LayoutOrder = 1,
				Size = tokens.TogglePillSize,
				[React.Event.Activated] = function()
					layersTool:setVisible(layerId, not layer.visible)
				end,
			}),
			label = createElement("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = fonts.ButtonFont.Font,
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, 32),
				Text = layer.name,
				TextColor3 = tokens.Colors.ContentEmphasis,
				TextSize = fonts.ButtonFont.FontSize,
				TextTransparency = if layer.visible then 0 else disabled,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				flexItem = createElement("UIFlexItem", {
					FlexMode = Enum.UIFlexMode.Fill,
				}),
			}),
			up = arrowButton(CreationStrings.layerMoveUp, 3, index < layerCount, function()
				layersTool:moveLayer(layerId, 1)
			end),
			down = arrowButton(CreationStrings.layerMoveDown, 4, index > 1, function()
				layersTool:moveLayer(layerId, -1)
			end),
			delete = createElement(IconButton, {
				icon = CreationIcons.icons.Delete,
				iconSize = tokens.IconSize.Small,
				iconTransparency = if state.canDelete then 0 else disabled,
				onActivated = function()
					if state.canDelete then
						layersTool:deleteLayer(layerId)
					end
				end,
				native = layerButton(5, {}),
			}, {
				corner = createElement("UICorner", {
					CornerRadius = tokens.Radius.Small,
				}),
			}),
		})
	end

	local activeBlendMode = CreationConfig.paintBlendModes.normal
	for _, layer in layers do
		if layer.id == state.activeLayerId then
			activeBlendMode = layer.blendMode
		end
	end

	return createElement(Panel, {
		title = CreationStrings.layersPanelTitle,
		visible = props.visible,
		onClose = props.onClose,
		onTrash = function()
			layersTool:deleteLayer(state.activeLayerId)
		end,
	}, {
		scrollFrame = createElement(ScrollFrame, {
			layoutOrder = 1,
		}, {
			layerList = createElement(ToolFrame, {
				layoutOrder = 1,
				title = string.format(CreationStrings.layerCountFormat, layerCount, CreationConfig.maxPaintLayers),
				titleAccessory = createElement("TextButton", {
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = tokens.ActionEmphasis.Color3,
					BackgroundTransparency = tokens.ActionEmphasis.Transparency,
					BorderSizePixel = 0,
					FontFace = fonts.ButtonFont.Font,
					LayoutOrder = 2,
					Size = UDim2.fromOffset(0, 28),
					Text = CreationStrings.addLayer,
					TextColor3 = tokens.Colors.ContentEmphasis,
					TextSize = fonts.CounterLabelFont.FontSize,
					Visible = state.canAdd,
					[React.Event.Activated] = function()
						layersTool:addLayer()
					end,
				}, {
					corner = createElement("UICorner", {
						CornerRadius = tokens.Radius.Circle,
					}),
					padding = createElement("UIPadding", {
						PaddingLeft = tokens.Padding.Medium,
						PaddingRight = tokens.Padding.Medium,
					}),
				}),
			}, {
				selectableList = createElement("Frame", {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 0),
				}, {
					listLayout = createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = tokens.Padding.XSmall,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					rows = createElement(React.Fragment, nil, rows),
				}),
			}),
			blendMode = createElement(ToolFrame, {
				layoutOrder = 2,
				title = CreationStrings.blendModeLabel,
			}, {
				segmentedControl = createElement(SegmentedControl, {
					fill = true,
					options = CreationConfig.paintBlendModeOrder,
					selectedIndex = table.find(CreationConfig.paintBlendModeOrder, activeBlendMode) or 1,
					onSelect = function(index: number)
						layersTool:setBlendMode(state.activeLayerId, CreationConfig.paintBlendModeOrder[index])
					end,
				}),
			}),
		}),
	})
end

return LayersPanel

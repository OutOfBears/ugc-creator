local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local React = require(ReplicatedStorage.Packages.React)

local ColorPicker = require("../../Components/ColorPicker")
local Panel = require("../../Components/Panel")
local ScrollFrame = require("../../Components/ScrollFrame")
local SegmentedControl = require("../../Components/SegmentedControl")
local SelectableRow = require("../../Components/SelectableRow")
local ToolFrame = require("../../Components/ToolFrame")
local useAtom = require("../../Hooks/useAtom")
local useCreationSession = require("../../Hooks/useCreationSession")
local useTheme = require("../../Hooks/useTheme")

local createElement = React.createElement
local useRef = React.useRef
local useState = React.useState

export type LayerColorPanelProps = {
	visible: boolean,
	onClose: () -> (),
	frameRef: ((Frame?) -> ())?,
}

local NO_ACCESSORIES = Charm.atom({})

local function toLabel(key: string): string
	return (string.gsub(key, "%.", " · "))
end

--[=[
	@class LayerColorPanel
	@client

	The layer recolor panel: a color picker editing the selected section, the list of the
	creation's sections (the head's, then each merged accessory's, prefixed with its slot) and one
	segmented control per variant group, driving [LayerColorTool]. Rebuilds when an accessory swap
	changes the sections.
]=]
local function LayerColorPanel(props: LayerColorPanelProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local fonts = theme.fonts

	local session = useCreationSession()
	local modelInfo = session.modelInfo
	local layerColorTool = session.layerColorTool
	local accessorySwapTool = session.accessorySwapTool

	useAtom(if accessorySwapTool then accessorySwapTool.selections else NO_ACCESSORIES)

	local activeSection, setActiveSection = useState(nil :: string?)
	local variantSelections, setVariantSelections = useState({} :: { [string]: number })

	local default = CreationConfig.defaultColorPickerColor
	local pickedColor = useRef(Color3.fromHSV(default.h, default.s, default.v))
	local pickedOpacity = useRef(1)

	local colorGroups = { { keyPrefix = "", catalog = modelInfo:getLayerCatalog() } }
	local accessoryCatalog = modelInfo:getAccessoryCatalog()
	if accessoryCatalog then
		for _, slot in accessoryCatalog.slots do
			local option = modelInfo:getSelectedAccessory(slot.name)
			if option then
				table.insert(colorGroups, { keyPrefix = `{slot.name}.`, catalog = option.colors })
			end
		end
	end

	local keys: { string } = {}
	local variantGroups = {}
	for _, colorGroup in colorGroups do
		for _, layer in colorGroup.catalog.layers do
			table.insert(keys, colorGroup.keyPrefix .. layer.name)
		end
		for _, group in colorGroup.catalog.variantGroups do
			table.insert(keys, colorGroup.keyPrefix .. group.name)
			table.insert(variantGroups, { key = colorGroup.keyPrefix .. group.name, group = group })
		end
	end

	local selectedSection = if activeSection and table.find(keys, activeSection) then activeSection else keys[1]

	local function applyColor(isFinalInput: boolean)
		if selectedSection then
			layerColorTool:applySectionColor(selectedSection, pickedColor.current, pickedOpacity.current, isFinalInput)
		end
	end

	local rows = {}
	for index, key in keys do
		rows[key] = createElement(SelectableRow, {
			layoutOrder = index,
			selected = key == selectedSection,
			onActivated = function()
				setActiveSection(key)
			end,
		}, {
			label = createElement("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = fonts.ButtonFont.Font,
				Size = UDim2.fromOffset(0, 32),
				Text = toLabel(key),
				TextColor3 = tokens.Colors.ContentEmphasis,
				TextSize = fonts.ButtonFont.FontSize,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				flexItem = createElement("UIFlexItem", {
					FlexMode = Enum.UIFlexMode.Fill,
				}),
			}),
		})
	end

	local tools: { [string]: any } = {
		colorTool = createElement(ToolFrame, {
			layoutOrder = 1,
			title = CreationStrings.toolTitles.color,
		}, {
			colorPicker = createElement(ColorPicker, {
				onColorChange = function(color: Color3, isFinalInput: boolean)
					pickedColor.current = color
					applyColor(isFinalInput)
				end,
				onOpacityChange = function(opacity: number)
					pickedOpacity.current = opacity
					applyColor(true)
				end,
			}),
		}),
		sectionsTool = createElement(ToolFrame, {
			layoutOrder = 2,
			title = CreationStrings.toolTitles.sections,
		}, {
			sectionList = createElement("Frame", {
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
	}

	for groupIndex, variantGroup in variantGroups do
		local options = {}
		for optionIndex, groupOption in variantGroup.group.options do
			options[optionIndex] = groupOption.name
		end

		tools[`variant_{variantGroup.key}`] = createElement(ToolFrame, {
			layoutOrder = 2 + groupIndex,
			title = toLabel(variantGroup.key),
		}, {
			segmentedControl = createElement(SegmentedControl, {
				fill = true,
				options = options,
				selectedIndex = variantSelections[variantGroup.key] or 1,
				onSelect = function(optionIndex: number)
					layerColorTool:selectVariant(variantGroup.key, optionIndex)

					local nextSelections = table.clone(variantSelections)
					nextSelections[variantGroup.key] = optionIndex
					setVariantSelections(nextSelections)
				end,
			}),
		})
	end

	return createElement(Panel, {
		title = CreationStrings.panelTitles.layerColor,
		visible = props.visible,
		onClose = props.onClose,
		frameRef = props.frameRef,
		onTrash = function() end,
	}, {
		scrollFrame = createElement(ScrollFrame, {
			layoutOrder = 1,
		}, tools),
	})
end

return LayerColorPanel

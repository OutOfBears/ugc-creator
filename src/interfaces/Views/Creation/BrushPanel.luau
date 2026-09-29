local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local React = require(ReplicatedStorage.Packages.React)

local ColorPicker = require("../../Components/ColorPicker")
local Panel = require("../../Components/Panel")
local ScrollFrame = require("../../Components/ScrollFrame")
local Slider = require("../../Components/Slider")
local ToggleButton = require("../../Components/ToggleButton")
local ToolFrame = require("../../Components/ToolFrame")
local useCreationSession = require("../../Hooks/useCreationSession")

local createElement = React.createElement

export type BrushPanelProps = {
	visible: boolean,
	onClose: () -> (),
}

--[=[
	@class BrushPanel
	@client

	The paintbrush panel: a size slider, a color picker with opacity, and the reflectivity toggle,
	all driving [BrushTool].
]=]
local function BrushPanel(props: BrushPanelProps)
	local brushTool = useCreationSession().brushTool
	local sizeRange = CreationConfig.maxBrushSize - CreationConfig.minBrushSize

	return createElement(Panel, {
		title = CreationStrings.panelTitles.brush,
		visible = props.visible,
		onClose = props.onClose,
		onTrash = function()
			brushTool:clearAll()
		end,
	}, {
		scrollFrame = createElement(ScrollFrame, {
			layoutOrder = 1,
		}, {
			sizeTool = createElement(ToolFrame, {
				layoutOrder = 1,
				title = CreationStrings.toolTitles.brushSize,
			}, {
				slider = createElement(Slider, {
					defaultValue = CreationConfig.defaultBrushSize / sizeRange,
					onChange = function(value: number, isFinalInput: boolean)
						brushTool:onBrushSizeChanged(value * sizeRange + CreationConfig.minBrushSize, isFinalInput)
					end,
				}),
			}),
			colorTool = createElement(ToolFrame, {
				layoutOrder = 2,
				title = CreationStrings.toolTitles.color,
				titleAccessory = createElement(ToggleButton, {
					label = CreationStrings.reflectivityToggle,
					layoutOrder = 2,
					onToggle = function(isOn: boolean)
						brushTool:setIsReflective(isOn)
					end,
				}),
			}, {
				colorPicker = createElement(ColorPicker, {
					onColorChange = function(color: Color3)
						brushTool:onColorChanged(color)
					end,
					onOpacityChange = function(opacity: number)
						brushTool:setTransparency(opacity)
					end,
				}),
			}),
		}),
	})
end

return BrushPanel

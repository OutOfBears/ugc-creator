local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local React = require(ReplicatedStorage.Packages.React)

local Panel = require("../../Components/Panel")
local Slider = require("../../Components/Slider")
local ToolFrame = require("../../Components/ToolFrame")
local useCreationSession = require("../../Hooks/useCreationSession")

local createElement = React.createElement

export type EraserPanelProps = {
	visible: boolean,
	onClose: () -> (),
}

--[=[
	@class EraserPanel
	@client

	The eraser panel: a size slider driving [BrushTool].
]=]
local function EraserPanel(props: EraserPanelProps)
	local brushTool = useCreationSession().brushTool
	local sizeRange = CreationConfig.maxBrushSize - CreationConfig.minBrushSize

	return createElement(Panel, {
		title = CreationStrings.panelTitles.eraser,
		visible = props.visible,
		onClose = props.onClose,
		onTrash = function()
			brushTool:clearAll()
		end,
	}, {
		sizeTool = createElement(ToolFrame, {
			layoutOrder = 1,
			title = CreationStrings.toolTitles.brushSize,
		}, {
			slider = createElement(Slider, {
				defaultValue = CreationConfig.defaultEraserSize / sizeRange,
				onChange = function(value: number, isFinalInput: boolean)
					brushTool:onBrushSizeChanged(value * sizeRange + CreationConfig.minBrushSize, isFinalInput)
				end,
			}),
		}),
	})
end

return EraserPanel

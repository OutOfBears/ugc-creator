local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local React = require(ReplicatedStorage.Packages.React)

local ColorPicker = require("../../Components/ColorPicker")
local Panel = require("../../Components/Panel")
local RegionPicker = require("../../Components/RegionPicker")
local ScrollFrame = require("../../Components/ScrollFrame")
local ToggleButton = require("../../Components/ToggleButton")
local ToolFrame = require("../../Components/ToolFrame")
local useCreationSession = require("../../Hooks/useCreationSession")

local createElement = React.createElement
local useMemo = React.useMemo

export type FillPanelProps = {
	visible: boolean,
	onClose: () -> (),
}

--[=[
	@class FillPanel
	@client

	The recolor panel: a region picker, a color picker with opacity and the reflectivity toggle,
	filling whole regions through [FabricTool].
]=]
local function FillPanel(props: FillPanelProps)
	local session = useCreationSession()
	local fabricTool = session.fabricTool

	local regionParts = useMemo(function()
		return session.modelInfo:getRegionPartsList()
	end, { session })
	local modelName = CreationStrings.modelDisplayName[regionParts[1]]

	return createElement(Panel, {
		title = CreationStrings.panelTitles.recolor,
		visible = props.visible,
		onClose = props.onClose,
		onTrash = function()
			fabricTool:clearAll()
		end,
	}, {
		scrollFrame = createElement(ScrollFrame, {
			layoutOrder = 1,
		}, {
			regionTool = createElement(ToolFrame, {
				layoutOrder = 1,
				title = string.format(CreationStrings.regionSectionFormat, tostring(modelName)),
			}, {
				regionPicker = createElement(RegionPicker, {
					regionParts = regionParts,
					onSelect = function(regionName: string)
						fabricTool:setSelectedRegion(regionName)
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
						fabricTool:setIsReflective(isOn)
						fabricTool:reapplyFillForReflectivity()
					end,
				}),
			}, {
				colorPicker = createElement(ColorPicker, {
					onColorChange = function(color: Color3, isFinalInput: boolean)
						fabricTool:applyColor(color, isFinalInput)
					end,
					onOpacityChange = function(opacity: number)
						fabricTool:setOpacity(opacity)
					end,
				}),
			}),
		}),
	})
end

return FillPanel

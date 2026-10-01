local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local React = require(ReplicatedStorage.Packages.React)
local Stickers = require(ReplicatedStorage.Shared.Data.Stickers)

local Panel = require("../../Components/Panel")
local ProgressBar = require("../../Components/ProgressBar")
local RegionPicker = require("../../Components/RegionPicker")
local ScrollFrame = require("../../Components/ScrollFrame")
local Slider = require("../../Components/Slider")
local TileGrid = require("../../Components/TileGrid")
local ToolFrame = require("../../Components/ToolFrame")
local useAtom = require("../../Hooks/useAtom")
local useCreationSession = require("../../Hooks/useCreationSession")

local createElement = React.createElement
local useMemo = React.useMemo

export type PatternPanelProps = {
	visible: boolean,
	onClose: () -> (),
	frameRef: ((Frame?) -> ())?,
}

--[=[
	@class PatternPanel
	@client

	The pattern panel: a sticker counter, a grid of stickers to tile across the creation, a padding
	slider and, where regional patterning is allowed, a region picker, driving [StickerTool].
	Whichever of the region picker and slider comes first stays pinned above the scrolling grid.
]=]
local function PatternPanel(props: PatternPanelProps)
	local session = useCreationSession()
	local stickerTool = session.stickerTool
	local state = useAtom(stickerTool.state)

	local regionParts = useMemo(function()
		return if session.modelInfo:getRegionalStickerPatterningEnabled()
			then session.modelInfo:getRegionPartsList()
			else nil
	end, { session })

	local paddingRange = CreationConfig.maxStickerPadding - CreationConfig.minStickerPadding

	local tiles = {}
	for _, sticker in Stickers do
		table.insert(tiles, {
			icon = sticker.textureId,
			onActivated = function()
				stickerTool:applySticker(sticker.textureId)
				stickerTool:setPatterned(true)
			end,
		})
	end

	local function paddingTool(layoutOrder: number)
		return createElement(ToolFrame, {
			layoutOrder = layoutOrder,
			title = CreationStrings.toolTitles.padding,
		}, {
			slider = createElement(Slider, {
				defaultValue = 0,
				onChange = function(value: number, isFinalInput: boolean)
					stickerTool:onPatternPaddingChanged(
						value * paddingRange + CreationConfig.minStickerPadding,
						isFinalInput
					)
				end,
			}),
		})
	end

	local function patternTool(layoutOrder: number)
		return createElement(ToolFrame, {
			layoutOrder = layoutOrder,
			title = CreationStrings.toolTitles.pattern,
		}, {
			grid = createElement(TileGrid, {
				tiles = tiles,
			}),
		})
	end

	local pinnedTool
	local scrolledTools
	if regionParts then
		local modelName = CreationStrings.modelDisplayName[regionParts[1]]

		pinnedTool = createElement(ToolFrame, {
			layoutOrder = 2,
			title = string.format(CreationStrings.regionSectionFormat, tostring(modelName)),
		}, {
			regionPicker = createElement(RegionPicker, {
				regionParts = regionParts,
				onSelect = function(regionName: string)
					stickerTool:setSelectedRegion(regionName)
				end,
			}),
		})
		scrolledTools = {
			paddingTool = paddingTool(1),
			patternTool = patternTool(2),
		}
	else
		pinnedTool = paddingTool(2)
		scrolledTools = {
			patternTool = patternTool(1),
		}
	end

	return createElement(Panel, {
		title = CreationStrings.panelTitles.pattern,
		visible = props.visible,
		onClose = props.onClose,
		frameRef = props.frameRef,
		onTrash = function()
			stickerTool:deleteCurrentSticker()
		end,
	}, {
		counter = createElement(ProgressBar, {
			label = CreationStrings.counters.sticker,
			layoutOrder = 1,
			maxValue = CreationConfig.maxStickerLayers,
			value = state.count,
		}),
		pinnedTool = pinnedTool,
		scrollFrame = createElement(ScrollFrame, {
			layoutOrder = 3,
		}, scrolledTools),
	})
end

return PatternPanel

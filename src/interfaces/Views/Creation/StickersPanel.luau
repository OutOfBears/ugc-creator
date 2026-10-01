local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local React = require(ReplicatedStorage.Packages.React)
local Stickers = require(ReplicatedStorage.Shared.Data.Stickers)

local ItemSelector = require("../../Components/ItemSelector")
local Panel = require("../../Components/Panel")
local ScrollFrame = require("../../Components/ScrollFrame")
local TileGrid = require("../../Components/TileGrid")
local useAtom = require("../../Hooks/useAtom")
local useCreationSession = require("../../Hooks/useCreationSession")

local createElement = React.createElement

export type StickersPanelProps = {
	visible: boolean,
	onClose: () -> (),
	frameRef: ((Frame?) -> ())?,
}

--[=[
	@class StickersPanel
	@client

	The sticker panel: a picker over the applied sticker slots and a grid of stickers to stamp,
	driving [StickerTool]. Patterning lives in [PatternPanel].
]=]
local function StickersPanel(props: StickersPanelProps)
	local stickerTool = useCreationSession().stickerTool
	local state = useAtom(stickerTool.state)

	local tiles = {}
	for _, sticker in Stickers do
		table.insert(tiles, {
			icon = sticker.textureId,
			onActivated = function()
				stickerTool:applySticker(sticker.textureId)
			end,
		})
	end

	return createElement(Panel, {
		title = CreationStrings.panelTitles.stickers,
		visible = props.visible,
		onClose = props.onClose,
		frameRef = props.frameRef,
		onTrash = function()
			stickerTool:deleteCurrentSticker()
		end,
	}, {
		itemSelector = createElement(ItemSelector, {
			icons = state.textureIds,
			layoutOrder = 1,
			selectedIndex = state.selectedIndex,
			slotCount = CreationConfig.maxStickerLayers,
			onSelect = function(index: number)
				stickerTool:selectSticker(index)
			end,
		}),
		scrollFrame = createElement(ScrollFrame, {
			layoutOrder = 2,
		}, {
			grid = createElement(TileGrid, {
				tiles = tiles,
			}),
		}),
	})
end

return StickersPanel

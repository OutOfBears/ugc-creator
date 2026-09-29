local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local Kitbash = require(ReplicatedStorage.Shared.Data.Kitbash)
local React = require(ReplicatedStorage.Packages.React)

local Panel = require("../../Components/Panel")
local ProgressBar = require("../../Components/ProgressBar")
local ScrollFrame = require("../../Components/ScrollFrame")
local TileGrid = require("../../Components/TileGrid")
local useAtom = require("../../Hooks/useAtom")
local useCreationSession = require("../../Hooks/useCreationSession")

local createElement = React.createElement

export type KitbashPanelProps = {
	visible: boolean,
	onClose: () -> (),
	frameRef: ((Frame?) -> ())?,
}

--[=[
	@class KitbashPanel
	@client

	The add-ons panel: a counter of spent atlas slots over a grid of meshes to kitbash onto the
	creation, driving [KitbashTool].
]=]
local function KitbashPanel(props: KitbashPanelProps)
	local kitbashTool = useCreationSession().kitbashTool
	local pieceCount = useAtom(kitbashTool.pieceCount)

	local tiles = {}
	for _, piece in Kitbash do
		table.insert(tiles, {
			icon = piece.thumbnail,
			onActivated = function()
				kitbashTool:selectPiece(piece.name, piece.minScale, piece.maxScale)
			end,
		})
	end

	return createElement(Panel, {
		title = CreationStrings.panelTitles.kitbash,
		visible = props.visible,
		onClose = props.onClose,
		frameRef = props.frameRef,
		onTrash = function()
			kitbashTool:deleteCurrentPiece()
		end,
	}, {
		counter = createElement(ProgressBar, {
			label = CreationStrings.counters.kitbash,
			layoutOrder = 1,
			maxValue = CreationConfig.atlasMaxKitbashPieces,
			value = pieceCount,
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

return KitbashPanel

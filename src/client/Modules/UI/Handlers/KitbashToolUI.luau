local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local Kitbash = require(ReplicatedStorage.Shared.Data.Kitbash)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Panel = require("../Components/Panel")
local ProgressBar = require("../Components/ProgressBar")
local StyleConsts = require("../Style/StyleConsts")
local TileGrid = require("../Components/TileGrid")

export type KitbashToolUI = {
	-- vars
	kitbashData: Kitbash.Kitbash,
	kitbashTool: any,
	pieceCounter: ProgressBar.ProgressBar,
	panel: Panel.Panel,
	maid: Maid.Maid,
	-- methods
	updateProgress: (self: KitbashToolUI) -> (),
	open: (self: KitbashToolUI) -> (),
	close: (self: KitbashToolUI) -> (),
	destroy: (self: KitbashToolUI) -> (),
}

--[=[
	@class KitbashToolUI
	@client

	The add-ons panel: a grid of meshes to kitbash onto the creation, over a counter of how many
	of the atlas slots are spent. Owned by [EditingUI].
]=]
local function KitbashToolUI(
	onClosePanelCallback: () -> (),
	onDeleteCallback: () -> (),
	kitbashData: Kitbash.Kitbash,
	kitbashTool: any
): KitbashToolUI
	local maid = Maid.new()
	local object = {} :: KitbashToolUI

	object.kitbashData = kitbashData
	object.kitbashTool = kitbashTool
	object.maid = maid

	object.pieceCounter = maid:add(ProgressBar(CreationStrings.counters.kitbash, CreationConfig.atlasMaxKitbashPieces))

	local scrollingFrame = Create("ScrollingFrame", {
		Tags = { StyleConsts.tags.ScrollFrame },
	})

	local tileInfos = {}

	for _, kitbashPiece in object.kitbashData do
		local info = {
			iconId = kitbashPiece.thumbnail,
			callback = function()
				object.kitbashTool:selectPiece(kitbashPiece.name, kitbashPiece.minScale, kitbashPiece.maxScale)
				object:updateProgress()
			end,
		}
		table.insert(tileInfos, info)
	end

	local grid = TileGrid(tileInfos)
	grid.Name = "KitbashGrid"
	grid.Parent = scrollingFrame

	object.panel = maid:add(
		Panel("Add-Ons", onClosePanelCallback, onDeleteCallback, { object.pieceCounter.frame, scrollingFrame })
	)
	object.panel.frame.Name = "KitbashToolPanel"
	object.panel.frame.Visible = false

	--[=[
		@within KitbashToolUI

		Re-reads how many pieces the tool has placed and moves the counter to match.
	]=]
	function object:updateProgress()
		self.pieceCounter:updateProgress(#self.kitbashTool.placedPieces)
	end

	--[=[
		@within KitbashToolUI
	]=]
	function object:open()
		self.panel.frame.Visible = true
		self:updateProgress()
	end

	--[=[
		@within KitbashToolUI
	]=]
	function object:close()
		self.panel.frame.Visible = false
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return KitbashToolUI

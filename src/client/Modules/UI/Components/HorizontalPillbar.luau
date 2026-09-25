local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local IconButton = require("./IconButton")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleConsts = require("../Style/StyleConsts")
local StyleTokens = require(ReplicatedStorage.Shared.Data.StyleTokens)
local StyleUtils = require("../Style/StyleUtils")

export type HorizontalPillbar = {
	-- vars
	frame: Frame,
	buttonList: { TextButton },
	currentSelection: number,
	maid: Maid.Maid,
	-- methods
	applySelection: (self: HorizontalPillbar, newSelectionIndex: number) -> (),
	destroy: (self: HorizontalPillbar) -> (),
}

--[=[
	@class HorizontalPillbar
	@client

	A rounded stack of icon buttons with one selected at a time; the leftmost starts selected. Past
	`MaxLargePillbarButtons` entries the buttons switch to the compact styling so the row still fits.

	@param pillbarButtonStack { IconButton.IconButtonInfo } -- buttons in display order
	@return HorizontalPillbar
]=]
local function HorizontalPillbar(pillbarButtonStack: { IconButton.IconButtonInfo }): HorizontalPillbar
	local maid = Maid.new()
	local object = {} :: HorizontalPillbar

	object.maid = maid
	object.currentSelection = 1
	object.buttonList = {}

	object.frame = maid:add(Create("Frame", {
		Name = "HorizontalPillbar",
		Tags = { StyleConsts.tags.HorizontalPillbar },
	}) :: Frame)

	--[=[
		@within HorizontalPillbar
		@param newSelectionIndex number -- the button to move the selected styling onto
	]=]
	function object:applySelection(newSelectionIndex: number)
		if newSelectionIndex ~= self.currentSelection then
			StyleUtils.addStyleTag(self.buttonList[newSelectionIndex], StyleConsts.tags.ButtonSelected)
			StyleUtils.removeStyleTag(self.buttonList[self.currentSelection], StyleConsts.tags.ButtonSelected)
			self.currentSelection = newSelectionIndex
		end
	end

	function object:destroy()
		maid:doCleaning()
	end

	for i, pillbarButtonInfo in pillbarButtonStack do
		local pillbarButton = IconButton(pillbarButtonInfo.iconId, function()
			pillbarButtonInfo.callback()
			object:applySelection(i)
		end)

		pillbarButton.LayoutOrder = i

		if #pillbarButtonStack < StyleTokens.style.MaxLargePillbarButtons then
			StyleUtils.addStyleTag(pillbarButton, StyleConsts.tags.LargePillbarButton)
		else
			StyleUtils.addStyleTag(pillbarButton, StyleConsts.tags.SmallPillbarButton)
		end

		pillbarButton.Parent = object.frame
		table.insert(object.buttonList, pillbarButton)
	end

	StyleUtils.addStyleTag(object.buttonList[1], StyleConsts.tags.ButtonSelected)

	return object
end

return HorizontalPillbar

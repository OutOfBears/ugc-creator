local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")
local TextButton = require("./TextButton")

export type SegmentedControl = {
	-- vars
	frame: Frame,
	buttonList: { TextButton },
	currentSelection: number,
	maid: Maid.Maid,
	-- methods
	applySelection: (self: SegmentedControl, newSelectionIndex: number) -> (),
	destroy: (self: SegmentedControl) -> (),
}

--[=[
	@class SegmentedControl
	@client

	Horizontal bar of labelled segments with one selected at a time; the first starts selected. Used
	by the avatar preview switcher.

	@param buttonInfos { TextButton.ButtonInfo } -- segments in display order
	@return SegmentedControl
]=]
local function SegmentedControl(buttonInfos: { TextButton.ButtonInfo }): SegmentedControl
	local maid = Maid.new()
	local object = {} :: SegmentedControl

	object.maid = maid
	object.currentSelection = 1
	object.buttonList = {}

	object.frame = maid:add(Create("Frame", {
		Name = "SegmentedControl",
		Tags = { StyleConsts.tags.SegmentedControl },
	}) :: Frame)

	--[=[
		@within SegmentedControl
		@param newSelectionIndex number -- the segment to move the selected styling onto
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

	for i, buttonInfo in buttonInfos do
		local button = Create("TextButton", {
			Text = buttonInfo.text,
			LayoutOrder = i,
			Tags = { StyleConsts.tags.SegmentedControlButton },
			Parent = object.frame,
		}) :: TextButton

		button.Activated:Connect(function()
			buttonInfo.callback()
			object:applySelection(i)
		end)

		table.insert(object.buttonList, button)
	end

	StyleUtils.addStyleTag(object.buttonList[1], StyleConsts.tags.ButtonSelected)

	return object
end

return SegmentedControl

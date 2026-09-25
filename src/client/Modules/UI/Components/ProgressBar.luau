local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleConsts = require("../Style/StyleConsts")

export type ProgressBar = {
	-- vars
	frame: Frame,
	label: TextLabel,
	progressFrame: Frame,
	labelText: string,
	maxValue: number,
	maid: Maid.Maid,
	-- methods
	updateProgress: (self: ProgressBar, currentValue: number) -> (),
	destroy: (self: ProgressBar) -> (),
}

--[=[
	@class ProgressBar
	@client

	Bar displaying a count against a maximum. Used to track applied stickers and kitbash pieces.

	@param labelText string -- trailing copy on the label, e.g. "Stickers Applied"
	@param maxValue number -- the count the bar fills at
	@return ProgressBar
]=]
local function ProgressBar(labelText: string, maxValue: number): ProgressBar
	local maid = Maid.new()
	local object = {} :: ProgressBar

	object.maid = maid
	object.maxValue = maxValue
	object.labelText = labelText

	object.frame = maid:add(Create("Frame", {
		Name = "ProgressBarFrame",
		Tags = { StyleConsts.tags.ProgressBarFrame },
	}) :: Frame)

	object.label = Create("TextLabel", {
		Name = "Label",
		Text = `0/{maxValue} {labelText}`,
		LayoutOrder = 2,
		Tags = { StyleConsts.tags.ProgressBarLabel },
		Parent = object.frame,
	}) :: TextLabel

	object.progressFrame = Create("Frame", {
		Name = "Progress",
		Size = UDim2.fromScale(0, 1),
		Tags = { StyleConsts.tags.ProgressBarProgress },
	}) :: Frame

	Create("Frame", {
		Name = "BarBackground",
		LayoutOrder = 1,
		Tags = { StyleConsts.tags.ProgressBarBackground },
		Children = { object.progressFrame },
		Parent = object.frame,
	})

	--[=[
		@within ProgressBar
		@param currentValue number -- the new count; must not exceed the bar's maximum
	]=]
	function object:updateProgress(currentValue: number)
		assert(currentValue <= self.maxValue, "Cannot have above 100% progress")

		self.progressFrame.Size = UDim2.fromScale(currentValue / self.maxValue, 1)
		self.label.Text = `{currentValue}/{self.maxValue} {self.labelText}`
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return ProgressBar

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleConsts = require("../Style/StyleConsts")

export type Counter = {
	-- vars
	frame: Frame,
	label: TextLabel,
	maxValue: number,
	maid: Maid.Maid,
	-- methods
	updateProgress: (self: Counter, currentValue: number) -> (),
	destroy: (self: Counter) -> (),
}

--[=[
	@class Counter
	@client

	Simple counter used with the [ItemSelector] to track how many stickers or add-ons are applied.

	@param maxValue number -- the denominator shown in the label
	@return Counter
]=]
local function Counter(maxValue: number): Counter
	local maid = Maid.new()
	local object = {} :: Counter

	object.maid = maid
	object.maxValue = maxValue

	object.frame = maid:add(Create("Frame", {
		Name = "CounterFrame",
		Tags = { StyleConsts.tags.CounterFrame },
	}) :: Frame)

	object.label = Create("TextLabel", {
		Name = "CounterLabel",
		Text = `0/{maxValue} Applied`,
		LayoutOrder = 2,
		Tags = { StyleConsts.tags.CounterLabel },
		Parent = object.frame,
	}) :: TextLabel

	--[=[
		@within Counter
		@param currentValue number -- the new count to display
	]=]
	function object:updateProgress(currentValue: number)
		self.label.Text = `{currentValue}/{self.maxValue}`
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return Counter

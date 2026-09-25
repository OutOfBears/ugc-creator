local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")

export type Slider = {
	-- vars
	frame: Frame,
	sliderInput: TextButton,
	sliderBarProgress: Frame,
	dragDetector: UIDragDetector,
	value: number,
	onValueChangedCallback: (number, boolean) -> (),
	maid: Maid.Maid,
	-- methods
	updateValue: (self: Slider, value: number, isFinalInput: boolean) -> (),
	destroy: (self: Slider) -> (),
}

--[=[
	@class Slider
	@client

	Generic slider, used for paintbrush size and sticker spacing. The input area is deliberately
	taller than the visible bar so it stays comfortable to grab on touch.

	@param defaultValue number -- starting value, 0 to 1
	@param onValueChangedCallback (value: number, isFinalInput: boolean) -> () -- fired on every drag step, with `isFinalInput` true on release
	@return Slider
]=]
local function Slider(defaultValue: number, onValueChangedCallback: (number, boolean) -> ()): Slider
	local maid = Maid.new()
	local object = {} :: Slider

	object.maid = maid
	object.value = defaultValue
	object.onValueChangedCallback = onValueChangedCallback

	object.frame = maid:add(Create("Frame", {
		Name = "Slider",
		Tags = { StyleConsts.tags.SliderFrame },
	}) :: Frame)

	object.sliderInput = Create("TextButton", {
		Name = "SliderInput",
		Text = "",
		Tags = { StyleConsts.tags.SliderInput },
		Parent = object.frame,
	}) :: TextButton

	object.dragDetector = Create("UIDragDetector", {
		ResponseStyle = Enum.UIDragDetectorResponseStyle.CustomScale,
		Parent = object.sliderInput,
	}) :: UIDragDetector

	--[=[
		@within Slider
		@param value number -- the new value, 0 to 1
		@param isFinalInput boolean -- true when this is the last update of a drag
	]=]
	function object:updateValue(value: number, isFinalInput: boolean)
		self.value = value

		self.sliderBarProgress.Size = UDim2.fromScale(value, 1)
		self.onValueChangedCallback(value, isFinalInput)
	end

	function object:destroy()
		maid:doCleaning()
	end

	local topLeftInset = GuiService:GetInsetArea(Enum.ScreenInsets.None).Min

	local function updateFromDrag(inputPos: Vector2, isFinalInput: boolean)
		local value = StyleUtils.getMousePositionScaleOnComponent(object.sliderInput, inputPos + topLeftInset).X
		object:updateValue(value, isFinalInput)
	end

	maid:giveTask(object.dragDetector.DragStart:Connect(function(inputPos)
		updateFromDrag(inputPos, false)
	end))
	maid:giveTask(object.dragDetector.DragContinue:Connect(function(inputPos)
		updateFromDrag(inputPos, false)
	end))
	maid:giveTask(object.dragDetector.DragEnd:Connect(function(inputPos)
		updateFromDrag(inputPos, true)
	end))

	local sliderBar = Create("Frame", {
		Name = "SliderBar",
		Tags = { StyleConsts.tags.SliderBar },
		Parent = object.frame,
	})

	object.sliderBarProgress = Create("Frame", {
		Name = "BarProgress",
		Parent = sliderBar,
	}) :: Frame

	Create("Frame", {
		Name = "SliderHandle",
		Tags = { StyleConsts.tags.SliderHandle },
		Parent = object.sliderBarProgress,
	})

	object:updateValue(object.value, true)

	return object
end

return Slider

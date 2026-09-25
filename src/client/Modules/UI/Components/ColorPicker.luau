local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")

export type ColorPicker = {
	-- vars
	frame: Frame,
	satValPicker: Frame,
	satValColorDot: Frame,
	huePicker: Frame,
	hueColorDot: Frame,
	opacityPicker: ImageLabel,
	opacityDot: Frame,
	opacityGradient: UIGradient,
	h: number,
	s: number,
	v: number,
	opacity: number,
	onColorChangedCallback: (color: Color3, isInputEnding: boolean) -> (),
	onOpacityChangedCallback: ((opacity: number) -> ())?,
	maid: Maid.Maid,
	-- methods
	getColor: (self: ColorPicker) -> Color3,
	getOpacity: (self: ColorPicker) -> number,
	setHue: (self: ColorPicker, mousePositionScale: Vector2) -> (),
	setSatVal: (self: ColorPicker, mousePositionScale: Vector2) -> (),
	setOpacity: (self: ColorPicker, mousePositionScale: Vector2) -> (),
	updateOpacityGradient: (self: ColorPicker) -> (),
	destroy: (self: ColorPicker) -> (),
}

local function makeColorDot(): Frame
	return Create("Frame", {
		Name = "ColorDot",
		Tags = { StyleConsts.tags.ColorDot },
	}) :: Frame
end

--[=[
	@class ColorPicker
	@client

	Color picker with a hue bar, a saturation/value field and an opacity bar. Unlike most components
	it restyles itself as the color changes, so the gradients and dots are driven here rather than
	from [StyleRules].

	@param colorPickerCallback (color: Color3, isInputEnding: boolean) -> () -- fired throughout a drag, with `isInputEnding` true on release
	@param opacityPickerCallback ((opacity: number) -> ())? -- fired when the opacity bar moves
	@return ColorPicker
]=]
local function ColorPicker(
	colorPickerCallback: (color: Color3, isInputEnding: boolean) -> (),
	opacityPickerCallback: ((opacity: number) -> ())?
): ColorPicker
	local maid = Maid.new()
	local object = {} :: ColorPicker

	object.maid = maid
	object.onColorChangedCallback = colorPickerCallback
	object.onOpacityChangedCallback = opacityPickerCallback

	object.h = StyleConsts.defaultColorPickerColor.h
	object.s = StyleConsts.defaultColorPickerColor.s
	object.v = StyleConsts.defaultColorPickerColor.v
	object.opacity = 1

	--[=[
		@within ColorPicker
		@return Color3 -- the currently picked color, ignoring opacity
	]=]
	function object:getColor(): Color3
		return Color3.fromHSV(self.h, self.s, self.v)
	end

	--[=[
		@within ColorPicker
		@return number -- the currently picked opacity, 0 to 1
	]=]
	function object:getOpacity(): number
		return self.opacity
	end

	--[=[
		@within ColorPicker

		Repaints the opacity bar's gradient and dot to match the current color.
	]=]
	function object:updateOpacityGradient()
		if not self.opacityGradient then
			return
		end

		local color = self:getColor()

		self.opacityGradient.Color = ColorSequence.new(color)

		if self.opacityDot then
			self.opacityDot.BackgroundColor3 = color
			self.opacityDot.BackgroundTransparency = 1 - self.opacity
		end
	end

	--[=[
		@within ColorPicker
		@param mousePositionScale Vector2 -- pointer position within the sat/val field, 0 to 1
	]=]
	function object:setSatVal(mousePositionScale: Vector2)
		self.s = mousePositionScale.X
		self.v = 1 - mousePositionScale.Y

		self.satValColorDot.BackgroundColor3 = self:getColor()
		self.satValColorDot.Position = UDim2.fromScale(mousePositionScale.X, mousePositionScale.Y)

		self:updateOpacityGradient()
	end

	--[=[
		@within ColorPicker
		@param mousePositionScale Vector2 -- pointer position within the hue bar, 0 to 1
	]=]
	function object:setHue(mousePositionScale: Vector2)
		self.h = mousePositionScale.X
		local hueColor = Color3.fromHSV(self.h, 1, 1)

		self.satValPicker.BackgroundColor3 = hueColor
		self.satValColorDot.BackgroundColor3 = self:getColor()

		self.hueColorDot.BackgroundColor3 = hueColor
		self.hueColorDot.Position = UDim2.fromScale(self.h, 0.5)

		self:updateOpacityGradient()
	end

	--[=[
		@within ColorPicker
		@param mousePositionScale Vector2 -- pointer position within the opacity bar, 0 to 1
	]=]
	function object:setOpacity(mousePositionScale: Vector2)
		self.opacity = math.clamp(mousePositionScale.X, 0, 1)

		if self.opacityDot then
			self.opacityDot.Position = UDim2.fromScale(self.opacity, 0.5)
			self.opacityDot.BackgroundColor3 = self:getColor()
			self.opacityDot.BackgroundTransparency = 1 - self.opacity
		end

		if self.onOpacityChangedCallback then
			self.onOpacityChangedCallback(self.opacity)
		end
	end

	function object:destroy()
		maid:doCleaning()
	end

	local function connectDragDetector(dragDetector: UIDragDetector, setPropertyCallback: (Vector2) -> ())
		local topLeftInset = GuiService:GetInsetArea(Enum.ScreenInsets.None).Min

		dragDetector.ResponseStyle = Enum.UIDragDetectorResponseStyle.CustomScale

		local target = dragDetector.Parent
		assert(target and target:IsA("GuiObject"), "UI Drag Detector must be parented to a GuiObject")

		local function apply(inputPos: Vector2, isInputEnding: boolean)
			setPropertyCallback(StyleUtils.getMousePositionScaleOnComponent(target, inputPos + topLeftInset))
			object.onColorChangedCallback(object:getColor(), isInputEnding)
		end

		maid:giveTask(dragDetector.DragStart:Connect(function(inputPos)
			apply(inputPos, false)
		end))
		maid:giveTask(dragDetector.DragContinue:Connect(function(inputPos)
			apply(inputPos, false)
		end))
		maid:giveTask(dragDetector.DragEnd:Connect(function(inputPos)
			apply(inputPos, true)
		end))
	end

	local function makeSatValPicker(): Frame
		local satValPicker = Create("Frame", {
			Name = "SatValPicker",
			BackgroundColor3 = Color3.fromHSV(object.h, 1, 1),
			Tags = { StyleConsts.tags.SatValPicker },
			Children = {
				Create("Frame", {
					Name = "SatGradient",
					Tags = { StyleConsts.tags.SatGradient },
				}),
				Create("Frame", {
					Name = "ValGradient",
					Tags = { StyleConsts.tags.ValGradient },
				}),
			},
		}) :: Frame

		local dragDetector = Create("UIDragDetector", {
			Parent = satValPicker,
		}) :: UIDragDetector

		connectDragDetector(dragDetector, function(scaleInput: Vector2)
			object:setSatVal(scaleInput)
		end)

		return satValPicker
	end

	local function makeHuePicker(): Frame
		local huePicker = Create("Frame", {
			Name = "HuePicker",
			Tags = { StyleConsts.tags.HuePicker },
		}) :: Frame

		local dragDetector = Create("UIDragDetector", {
			Parent = huePicker,
		}) :: UIDragDetector

		connectDragDetector(dragDetector, function(scalePosition: Vector2)
			object:setHue(scalePosition)
		end)

		return huePicker
	end

	local function makeOpacitySlider(): ImageLabel
		local opacityPicker = Create("ImageLabel", {
			Name = "OpacityPicker",
			Tags = { StyleConsts.tags.OpacityPicker },
		}) :: ImageLabel

		local opacityOverlay = Create("Frame", {
			Name = "OpacityOverlay",
			Tags = { StyleConsts.tags.OpacityOverlay },
			Parent = opacityPicker,
		})

		object.opacityGradient = Create("UIGradient", {
			Name = "OpacityGradient",
			Tags = { StyleConsts.tags.OpacityGradient },
			Parent = opacityOverlay,
		}) :: UIGradient

		object.opacityDot = makeColorDot()
		object.opacityDot.Name = "OpacityDot"
		object.opacityDot.Position = UDim2.fromScale(object.opacity, 0.5)
		object.opacityDot.BackgroundColor3 = object:getColor()
		object.opacityDot.Parent = opacityPicker
		object:updateOpacityGradient()

		local dragDetector = Create("UIDragDetector", {
			Parent = opacityPicker,
		}) :: UIDragDetector

		connectDragDetector(dragDetector, function(scalePosition: Vector2)
			object:setOpacity(scalePosition)
		end)

		return opacityPicker
	end

	object.frame = maid:add(Create("Frame", {
		Name = "ColorPicker",
		Tags = { StyleConsts.tags.ColorPicker },
	}) :: Frame)

	object.satValPicker = makeSatValPicker()
	object.satValPicker.LayoutOrder = 1
	object.satValPicker.Parent = object.frame

	object.satValColorDot = makeColorDot()
	object.satValColorDot.Position = UDim2.fromScale(object.s, 1 - object.v)
	object.satValColorDot.BackgroundColor3 = object:getColor()
	object.satValColorDot.Parent = object.satValPicker

	object.huePicker = makeHuePicker()
	object.huePicker.LayoutOrder = 2
	object.huePicker.Parent = object.frame

	object.hueColorDot = makeColorDot()
	object.hueColorDot.Position = UDim2.fromScale(object.h, 0.5)
	object.hueColorDot.BackgroundColor3 = Color3.fromHSV(object.h, 1, 1)
	object.hueColorDot.Parent = object.huePicker

	object.opacityPicker = makeOpacitySlider()
	object.opacityPicker.LayoutOrder = 3
	object.opacityPicker.Parent = object.frame

	return object
end

return ColorPicker

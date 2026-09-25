local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local StyleConsts = require("../Style/StyleConsts")

export type ToggleButtonInfo = {
	label: string,
	callback: (isOn: boolean) -> (),
	initialOn: boolean?,
}

local function setToggleImage(toggleButton: ImageButton, isOn: boolean)
	toggleButton.Image = if isOn then CreationIcons.uiImages.ToggleOn else CreationIcons.uiImages.ToggleOff
end

--[=[
	@class ToggleButton
	@client

	Labelled on/off pill. The pill image is swapped directly rather than through a tag, so the
	`TogglePill` rule only supplies the off-state image.

	@param toggleButtonInfo ToggleButtonInfo -- label, change callback, and optional starting state
	@return Frame -- the frame holding the pill and its label
]=]
local function ToggleButton(toggleButtonInfo: ToggleButtonInfo): Frame
	local toggleFrame = Create("Frame", {
		Name = "ToggleFrame",
		Tags = { StyleConsts.tags.ToggleFrame },
	}) :: Frame

	local isOn = toggleButtonInfo.initialOn == true

	local toggleButton = Create("ImageButton", {
		Name = "ToggleButton",
		Tags = { StyleConsts.tags.TogglePill },
		Parent = toggleFrame,
	}) :: ImageButton

	setToggleImage(toggleButton, isOn)

	toggleButton.Activated:Connect(function()
		isOn = not isOn
		setToggleImage(toggleButton, isOn)
		toggleButtonInfo.callback(isOn)
	end)

	Create("TextLabel", {
		Name = "ToggleLabel",
		Text = toggleButtonInfo.label,
		Tags = { StyleConsts.tags.ToggleLabel },
		Parent = toggleFrame,
	})

	return toggleFrame
end

return ToggleButton

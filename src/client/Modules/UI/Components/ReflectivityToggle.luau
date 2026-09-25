local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local ToggleButton = require("./ToggleButton")

--[=[
	@class ReflectivityToggle
	@client

	The [ToggleButton] that switches PBR colouring on and off in the texture editing modes.

	@param onReflectiveModeChanged (isReflective: boolean) -> () -- fired when the toggle flips
	@param initialOn boolean? -- starting state, defaults to off
	@return Frame -- the toggle frame
]=]
local function ReflectivityToggle(onReflectiveModeChanged: (isReflective: boolean) -> (), initialOn: boolean?): Frame
	return ToggleButton({
		label = CreationStrings.reflectivityToggle,
		initialOn = initialOn,
		callback = function(isOn: boolean)
			if onReflectiveModeChanged then
				onReflectiveModeChanged(isOn)
			end
		end,
	})
end

return ReflectivityToggle

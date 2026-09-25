local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local StyleConsts = require("../Style/StyleConsts")

export type ButtonInfo = {
	text: string,
	callback: () -> (),
}

--[=[
	@class TextButton
	@client

	Generic text button, used primarily for modals.

	@param buttonInfo ButtonInfo -- label and activation callback
	@return TextButton -- the button
]=]
local function TextButton(buttonInfo: ButtonInfo): TextButton
	local button = Create("TextButton", {
		Name = "TextButton",
		Text = buttonInfo.text,
		Tags = { StyleConsts.tags.DefaultButton },
	}) :: TextButton

	button.Activated:Connect(buttonInfo.callback)

	return button
end

return TextButton

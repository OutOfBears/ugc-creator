local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)

export type IconButtonInfo = {
	iconId: string,
	callback: () -> (),
}

--[=[
	@class IconButton
	@client

	Generic button with an icon. Carries no tag of its own — the caller or parent component tags it,
	and the matching rule in [StyleRules] sizes and positions the icon.

	@param iconAssetId string -- image id shown on the button
	@param onActivated (() -> ())? -- fired when the button is pressed
	@return TextButton -- the button, with its `ImageLabel` child already parented
]=]
local function IconButton(iconAssetId: string, onActivated: (() -> ())?): TextButton
	local iconButton = Create("TextButton", {
		Name = "IconButton",
		Text = "",
		Children = {
			Create("ImageLabel", {
				Image = iconAssetId,
				BackgroundTransparency = 1,
			}),
		},
	}) :: TextButton

	if onActivated then
		iconButton.Activated:Connect(onActivated)
	end

	return iconButton
end

return IconButton

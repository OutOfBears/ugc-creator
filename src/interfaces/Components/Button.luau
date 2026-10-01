local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Sift = require(ReplicatedStorage.Packages.Sift)

local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo

export type ButtonProps = {
	text: string,
	emphasis: boolean?,
	onActivated: () -> (),
	native: { [string]: any }?,
}

--[=[
	@class Button
	@client

	The standard text button, filled with the emphasis color when `emphasis` is set. Width comes
	from its layout unless `native` sets a size.
]=]
local Button = memo(function(props: ButtonProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local font = theme.fonts.ButtonFont
	local fill = if props.emphasis then tokens.ActionEmphasis else tokens.Shift_300

	return createElement(
		"TextButton",
		Sift.Dictionary.join({
			BackgroundColor3 = fill.Color3,
			BackgroundTransparency = fill.Transparency,
			BorderSizePixel = 0,
			FontFace = font.Font,
			Size = tokens.ButtonSize,
			Text = props.text,
			TextColor3 = tokens.Colors.ContentEmphasis,
			TextSize = font.FontSize,
			[React.Event.Activated] = props.onActivated,
		}, props.native or {}),
		{
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Medium,
			}),
			padding = createElement("UIPadding", {
				PaddingLeft = tokens.Padding.Large,
				PaddingRight = tokens.Padding.Large,
			}),
		}
	)
end)

return Button

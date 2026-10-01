local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Sift = require(ReplicatedStorage.Packages.Sift)

local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo

export type IconButtonProps = {
	icon: string,
	iconSize: UDim2,
	iconTransparency: number?,
	onActivated: (() -> ())?,
	children: React.ReactNode?,
	native: { [string]: any }?,
}

--[=[
	@class IconButton
	@client

	A text-less button with a centered icon. Size, background and corners come from the caller
	through `native` and `children`.
]=]
local IconButton = memo(function(props: IconButtonProps)
	local theme = useTheme()

	return createElement(
		"TextButton",
		Sift.Dictionary.join({
			BorderSizePixel = 0,
			Text = "",
			[React.Event.Activated] = props.onActivated,
		}, props.native or {}),
		Sift.Dictionary.join({
			icon = createElement("ImageLabel", {
				AnchorPoint = theme.tokens.CenterAnchor,
				BackgroundTransparency = 1,
				Image = props.icon,
				ImageTransparency = props.iconTransparency,
				Position = theme.tokens.CenterPosition,
				Size = props.iconSize,
			}),
		}, props.children or {})
	)
end)

return IconButton

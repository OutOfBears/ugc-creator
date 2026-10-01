local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo

export type SelectableRowProps = {
	selected: boolean,
	layoutOrder: number?,
	onActivated: () -> (),
	children: React.ReactNode?,
}

--[=[
	@class SelectableRow
	@client

	A full-width row button in a selectable list, laying its children out left to right and
	highlighting when selected.
]=]
local SelectableRow = memo(function(props: SelectableRowProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local background = if props.selected then tokens.Shift_300 else tokens.Surface_100

	return createElement("TextButton", {
		AutoButtonColor = false,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = background.Color3,
		BackgroundTransparency = background.Transparency,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 0),
		Text = "",
		[React.Event.Activated] = props.onActivated,
	}, {
		corner = createElement("UICorner", {
			CornerRadius = tokens.Radius.Medium,
		}),
		padding = createElement("UIPadding", {
			PaddingBottom = tokens.Padding.XSmall,
			PaddingLeft = tokens.Padding.Small,
			PaddingRight = tokens.Padding.XSmall,
			PaddingTop = tokens.Padding.XSmall,
		}),
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = tokens.Padding.XSmall,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		content = createElement(React.Fragment, nil, props.children),
	})
end)

return SelectableRow

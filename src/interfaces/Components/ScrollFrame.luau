local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo

export type ScrollFrameProps = {
	layoutOrder: number?,
	children: React.ReactNode?,
}

--[=[
	@class ScrollFrame
	@client

	A vertically scrolling column that fills the remaining panel height and stacks its children
	full width.
]=]
local ScrollFrame = memo(function(props: ScrollFrameProps)
	local theme = useTheme()

	return createElement("ScrollingFrame", {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(1, 0),
		LayoutOrder = props.layoutOrder,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
	}, {
		flexItem = createElement("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Fill,
		}),
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = theme.tokens.Padding.XLarge,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		content = createElement(React.Fragment, nil, props.children),
	})
end)

return ScrollFrame

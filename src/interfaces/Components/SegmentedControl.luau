local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Sift = require(ReplicatedStorage.Packages.Sift)

local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo

export type SegmentedControlProps = {
	options: { string },
	selectedIndex: number,
	onSelect: (index: number) -> (),
	fill: boolean?,
	native: { [string]: any }?,
}

--[=[
	@class SegmentedControl
	@client

	A bar of labelled segments with one selected. `fill` stretches it across its parent and shares
	the width between segments instead of using fixed-width segments.
]=]
local SegmentedControl = memo(function(props: SegmentedControlProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local fonts = theme.fonts
	local fill = props.fill == true

	local buttonHeight = tokens.SegmentedControlButtonSize.Y
	local padding = tokens.SegmentedControlPadding

	local children: { [string]: any } = {
		corner = createElement("UICorner", {
			CornerRadius = tokens.Radius.Medium,
		}),
		padding = createElement("UIPadding", {
			PaddingBottom = padding,
			PaddingLeft = padding,
			PaddingRight = padding,
			PaddingTop = padding,
		}),
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = tokens.Padding.XSmall,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, label in props.options do
		local isSelected = index == props.selectedIndex
		local background = if isSelected then tokens.Shift_300 else nil

		children[`segment{index}`] = createElement("TextButton", {
			AutoButtonColor = not isSelected,
			BackgroundColor3 = if background then background.Color3 else nil,
			BackgroundTransparency = if background then background.Transparency else 1,
			BorderSizePixel = 0,
			FontFace = fonts.SegmentedControlButtonFont.Font,
			LayoutOrder = index,
			Size = if fill
				then UDim2.new(0, 0, buttonHeight.Scale, buttonHeight.Offset)
				else tokens.SegmentedControlButtonSize,
			Text = label,
			TextColor3 = tokens.Colors.ContentDefault,
			TextSize = if fill then fonts.CounterLabelFont.FontSize else fonts.SegmentedControlButtonFont.FontSize,
			TextTruncate = Enum.TextTruncate.AtEnd,
			[React.Event.Activated] = function()
				props.onSelect(index)
			end,
		}, {
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Small,
			}),
			padding = createElement("UIPadding", {
				PaddingLeft = if fill then tokens.Padding.XXSmall else tokens.Padding.Small,
				PaddingRight = if fill then tokens.Padding.XXSmall else tokens.Padding.Small,
			}),
			flexItem = if fill
				then createElement("UIFlexItem", {
					FlexMode = Enum.UIFlexMode.Fill,
				})
				else nil,
		})
	end

	return createElement(
		"Frame",
		Sift.Dictionary.join({
			AutomaticSize = if fill then Enum.AutomaticSize.Y else Enum.AutomaticSize.XY,
			BackgroundColor3 = tokens.Surface_100.Color3,
			BackgroundTransparency = tokens.Surface_100.Transparency,
			BorderSizePixel = 0,
			Size = if fill then UDim2.fromScale(1, 0) else nil,
		}, props.native or {}),
		children
	)
end)

return SegmentedControl

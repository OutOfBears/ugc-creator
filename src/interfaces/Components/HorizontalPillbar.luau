local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo

export type HorizontalPillbarProps = {
	icons: { string },
	selectedIndex: number,
	onSelect: (index: number) -> (),
}

--[=[
	@class HorizontalPillbar
	@client

	A rounded row of icon buttons with one selected. From `MaxLargePillbarButtons` buttons up it
	switches to the compact button size so the row still fits.
]=]
local HorizontalPillbar = memo(function(props: HorizontalPillbarProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local isLarge = #props.icons < tokens.MaxLargePillbarButtons

	local children: { [string]: any } = {
		corner = createElement("UICorner", {
			CornerRadius = tokens.Radius.Circle,
		}),
		padding = createElement("UIPadding", {
			PaddingBottom = tokens.Padding.XSmall,
			PaddingLeft = tokens.Padding.XSmall,
			PaddingRight = tokens.Padding.XSmall,
			PaddingTop = tokens.Padding.XSmall,
		}),
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = tokens.Padding.XSmall,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local verticalPadding = if isLarge then tokens.LargePillbarVerticalPadding else tokens.Padding.XSmall
	local horizontalPadding = if isLarge then tokens.LargePillbarHorizontalPadding else tokens.Padding.XSmall

	for index, icon in props.icons do
		local isSelected = index == props.selectedIndex

		children[`button{index}`] = createElement("TextButton", {
			AutoButtonColor = not isSelected,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = if isSelected then tokens.Shift_300.Color3 else nil,
			BackgroundTransparency = if isSelected then tokens.Shift_300.Transparency else 1,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.fromScale(0, 0),
			Text = "",
			[React.Event.Activated] = function()
				props.onSelect(index)
			end,
		}, {
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Circle,
			}),
			-- Centering via layout alignment rather than an anchor point: anchors fight AutomaticSize.
			listLayout = createElement("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			padding = createElement("UIPadding", {
				PaddingBottom = verticalPadding,
				PaddingLeft = horizontalPadding,
				PaddingRight = horizontalPadding,
				PaddingTop = verticalPadding,
			}),
			icon = createElement("ImageLabel", {
				BackgroundTransparency = 1,
				Image = icon,
				Size = if isLarge then tokens.LargePillbarIconSize else tokens.IconSize.Small,
			}),
		})
	end

	return createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = tokens.Shift_300.Color3,
		BackgroundTransparency = tokens.Shift_300.Transparency,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
	}, children)
end)

return HorizontalPillbar

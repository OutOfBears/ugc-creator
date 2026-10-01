local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo

export type ProgressBarProps = {
	label: string,
	value: number,
	maxValue: number,
	layoutOrder: number?,
}

--[=[
	@class ProgressBar
	@client

	A thin bar filling toward `maxValue`, labelled `value/maxValue label`. Tracks applied stickers
	and add-ons.
]=]
local ProgressBar = memo(function(props: ProgressBarProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local labelFont = theme.fonts.CounterLabelFont

	return createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		Size = tokens.ProgressBarFrameSize,
	}, {
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			ItemLineAlignment = Enum.ItemLineAlignment.Center,
			Padding = tokens.Padding.Small,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		barBackground = createElement("Frame", {
			BackgroundColor3 = tokens.Shift_200.Color3,
			BackgroundTransparency = tokens.Shift_200.Transparency,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Size = tokens.ProgressBarBackgroundSize,
		}, {
			flexItem = createElement("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
			}),
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Circle,
			}),
			progress = createElement("Frame", {
				BackgroundColor3 = tokens.Colors.ContentEmphasis,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(props.value / props.maxValue, 1),
			}, {
				corner = createElement("UICorner", {
					CornerRadius = tokens.Radius.Circle,
				}),
			}),
		}),
		label = createElement("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = labelFont.Font,
			LayoutOrder = 2,
			Text = `{props.value}/{props.maxValue} {props.label}`,
			TextColor3 = tokens.Colors.ContentDefault,
			TextSize = labelFont.FontSize,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end)

return ProgressBar

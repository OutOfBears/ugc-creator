local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo

export type ToolFrameProps = {
	title: string,
	layoutOrder: number?,
	titleAccessory: React.ReactNode?,
	children: React.ReactNode?,
}

--[=[
	@class ToolFrame
	@client

	A titled block inside a panel: the title row (with optional content pinned right) above the
	tool it labels.
]=]
local ToolFrame = memo(function(props: ToolFrameProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local titleFont = theme.fonts.ToolTitleFont

	return createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 0),
	}, {
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = tokens.Padding.Large,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		toolTitle = createElement("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Size = tokens.ToolTitleSize,
		}, {
			listLayout = createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
				ItemLineAlignment = Enum.ItemLineAlignment.Center,
				Padding = tokens.Padding.Small,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			toolTitleLabel = createElement("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = titleFont.Font,
				LayoutOrder = 1,
				Text = props.title,
				TextColor3 = tokens.Colors.ContentEmphasis,
				TextSize = titleFont.FontSize,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			titleAccessory = props.titleAccessory,
		}),
		tool = createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0),
		}, props.children),
	})
end)

return ToolFrame

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local React = require(ReplicatedStorage.Packages.React)

local IconButton = require("./IconButton")
local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo

export type PanelProps = {
	title: string,
	visible: boolean,
	onClose: () -> (),
	onTrash: () -> (),
	children: React.ReactNode?,
}

--[=[
	@class Panel
	@client

	The side panel housing an editing tool: a header with the title, delete and close buttons above
	the tool body. Its size, corners and anchoring come from the theme layout, so it restyles
	between mobile and desktop.
]=]
local Panel = memo(function(props: PanelProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local layout = theme.layout
	local titleFont = theme.fonts.TitleLarge

	local function headerButton(icon: string, layoutOrder: number, onActivated: () -> ())
		return createElement(IconButton, {
			icon = icon,
			iconSize = tokens.IconSize.Large,
			onActivated = onActivated,
			native = {
				BackgroundTransparency = 1,
				LayoutOrder = layoutOrder,
				Size = tokens.IconButtonSize,
			},
		})
	end

	return createElement("Frame", {
		AnchorPoint = layout.PanelAnchorPoint,
		AutomaticSize = layout.PanelAutomaticSize,
		BackgroundColor3 = tokens.Surface_0.Color3,
		BackgroundTransparency = tokens.Surface_0.Transparency,
		BorderSizePixel = 0,
		Position = layout.PanelPosition,
		Size = layout.PanelSize,
		Visible = props.visible,
	}, {
		padding = createElement("UIPadding", {
			PaddingBottom = tokens.Padding.XLarge,
			PaddingLeft = tokens.Padding.Small,
			-- Wider than the left inset on purpose: device safe-area insets eat into this edge.
			PaddingRight = tokens.Padding.Medium,
			PaddingTop = tokens.Padding.Small,
		}),
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = tokens.Padding.Large,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		corner = createElement("UICorner", {
			CornerRadius = layout.PanelCornerRadius,
		}),
		sizeConstraint = createElement("UISizeConstraint", {
			MaxSize = layout.PanelMaxSize,
		}),
		header = createElement("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Size = tokens.PanelHeaderSize,
		}, {
			padding = createElement("UIPadding", {
				PaddingLeft = tokens.Padding.XLarge,
				PaddingRight = tokens.Padding.Medium,
			}),
			listLayout = createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = tokens.Padding.Medium,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			titleLabel = createElement("TextLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = titleFont.Font,
				LayoutOrder = 1,
				Size = UDim2.fromScale(0, 1),
				Text = props.title,
				TextColor3 = tokens.Colors.ContentEmphasis,
				TextSize = titleFont.FontSize,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			iconFrame = createElement("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = 2,
				Size = UDim2.fromScale(0, 1),
			}, {
				listLayout = createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					ItemLineAlignment = Enum.ItemLineAlignment.Center,
					Padding = tokens.Padding.XXSmall,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				trashButton = headerButton(CreationIcons.icons.Delete, 3, props.onTrash),
				closeButton = headerButton(CreationIcons.icons.XButton, 4, props.onClose),
			}),
		}),
		toolsContainer = createElement("Frame", {
			AutomaticSize = layout.PanelAutomaticSize,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 1),
		}, {
			flexItem = createElement("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
			}),
			padding = createElement("UIPadding", {
				PaddingBottom = tokens.Padding.XLarge,
				PaddingLeft = tokens.Padding.XLarge,
				PaddingRight = tokens.Padding.XLarge,
			}),
			listLayout = createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				Padding = tokens.Padding.XLarge,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			content = createElement(React.Fragment, nil, props.children),
		}),
	})
end)

return Panel

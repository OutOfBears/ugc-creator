local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local React = require(ReplicatedStorage.Packages.React)

local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo

export type ItemSelectorProps = {
	slotCount: number,
	icons: { string },
	selectedIndex: number,
	onSelect: (index: number) -> (),
	layoutOrder: number?,
}

--[=[
	@class ItemSelector
	@client

	A scrollable row of `slotCount` mini tiles showing the applied items, one selected, beside an
	applied/total counter. Empty slots stay inert.
]=]
local ItemSelector = memo(function(props: ItemSelectorProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local counterFont = theme.fonts.CounterLabelFont

	local tiles: { [string]: any } = {
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = tokens.Padding.Small,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index = 1, props.slotCount do
		local icon = props.icons[index]

		tiles[`tile{index}`] = createElement("Frame", {
			BackgroundColor3 = tokens.OverMedia_200.Color3,
			BackgroundTransparency = tokens.OverMedia_200.Transparency,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.fromScale(1, 1),
		}, {
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Medium,
			}),
			aspectRatio = createElement("UIAspectRatioConstraint", {
				AspectRatio = 1,
			}),
			stroke = if icon and index == props.selectedIndex
				then createElement("UIStroke", {
					BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					Color = tokens.System_Contrast.Color3,
					Thickness = tokens.Stroke_Default.Thickness,
					Transparency = tokens.System_Contrast.Transparency,
				})
				else nil,
			button = if icon
				then createElement("TextButton", {
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					Text = "",
					[React.Event.Activated] = function()
						props.onSelect(index)
					end,
				}, {
					icon = createElement("ImageLabel", {
						BackgroundTransparency = 1,
						Image = icon,
						Size = UDim2.fromScale(1, 1),
					}),
				})
				else nil,
		})
	end

	return createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
	}, {
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = tokens.Padding.Medium,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		flexFrame = createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}, {
			flexItem = createElement("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
			}),
			scrollFrame = createElement("ScrollingFrame", {
				AutomaticCanvasSize = Enum.AutomaticSize.XY,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				BottomImage = CreationIcons.scrollBar.Bottom,
				HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				MidImage = CreationIcons.scrollBar.Middle,
				ScrollBarImageColor3 = tokens.Shift_400.Color3,
				ScrollBarImageTransparency = tokens.Shift_400.Transparency,
				ScrollBarThickness = 4,
				ScrollingDirection = Enum.ScrollingDirection.X,
				Size = UDim2.fromScale(1, 0),
				TopImage = CreationIcons.scrollBar.Top,
			}, {
				padding = createElement("UIPadding", {
					PaddingBottom = tokens.Padding.XSmall,
				}),
				tileGroup = createElement("Frame", {
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = tokens.MiniBaseTileGroupSize,
				}, tiles),
			}),
		}),
		counter = createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 2,
			Size = UDim2.fromOffset(0, 0),
		}, {
			label = createElement("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = counterFont.Font,
				LayoutOrder = 2,
				Text = `{#props.icons}/{props.slotCount}`,
				TextColor3 = tokens.Colors.ContentDefault,
				TextSize = counterFont.FontSize,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),
	})
end)

return ItemSelector

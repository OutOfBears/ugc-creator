local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo

export type Tile = {
	icon: string?,
	selected: boolean?,
	onActivated: (() -> ())?,
}

export type TileGridProps = {
	tiles: { Tile },
}

--[=[
	@class TileGrid
	@client

	A grid of square thumbnail tiles in the given order. A tile without an icon stays empty and
	inert; a selected tile is outlined.
]=]
local TileGrid = memo(function(props: TileGridProps)
	local theme = useTheme()
	local tokens = theme.tokens

	local children: { [string]: any } = {
		padding = createElement("UIPadding", {
			PaddingBottom = tokens.Padding.XXSmall,
			PaddingLeft = tokens.Padding.XXSmall,
			PaddingRight = tokens.Padding.XXSmall,
			PaddingTop = tokens.Padding.XXSmall,
		}),
		gridLayout = createElement("UIGridLayout", {
			CellPadding = UDim2.new(tokens.Padding.Small, tokens.Padding.Small),
			CellSize = tokens.GridTileSize,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, tile in props.tiles do
		children[`tile{index}`] = createElement("Frame", {
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
			stroke = if tile.selected
				then createElement("UIStroke", {
					BorderStrokePosition = Enum.BorderStrokePosition.Inner,
					Color = tokens.System_Contrast.Color3,
					Thickness = tokens.Stroke_Default.Thickness,
					Transparency = tokens.System_Contrast.Transparency,
				})
				else nil,
			button = if tile.icon
				then createElement("TextButton", {
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 1),
					Text = "",
					[React.Event.Activated] = tile.onActivated,
				}, {
					icon = createElement("ImageLabel", {
						BackgroundTransparency = 1,
						Image = tile.icon,
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
		Size = UDim2.fromScale(1, 0),
	}, children)
end)

return TileGrid

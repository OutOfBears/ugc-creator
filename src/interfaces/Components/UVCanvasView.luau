local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local React = require(ReplicatedStorage.Packages.React)
local TextureUtils = require(ReplicatedStorage.Shared.Modules.Utils.TextureUtils)

local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo
local useEffect = React.useEffect
local useState = React.useState

export type ContentState = {
	position: Vector2,
	size: Vector2,
	pixelated: boolean,
}

export type CursorState = {
	visible: boolean,
	position: Vector2,
	diameter: number,
}

export type UVCanvasViewProps = {
	textureImage: EditableImage?,
	cellSize: Vector2,
	wireframeImage: EditableImage?,
	wireframeVisible: boolean,
	content: React.Binding<ContentState>,
	cursor: React.Binding<CursorState>,
	viewRef: { current: Frame? },
	resizeGripRef: { current: TextButton? },
	layoutOrder: number?,
	children: React.ReactNode?,
}

local function contentOf(image: EditableImage?): Content
	return if image then Content.fromObject(image) else Content.none
end

--[=[
	@class UVCanvasView
	@client

	A flat, zoomable view of a texture in UV space over a checkerboard, with an optional UV
	wireframe, a brush cursor and a resize grip. It only draws: zoom, pan and the cursor arrive as
	bindings, and `children` render in texture space (e.g. a sticker handle).
]=]
local UVCanvasView = memo(function(props: UVCanvasViewProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local fonts = theme.fonts
	local config = CreationConfig.uvCanvas

	local checkerImage, setCheckerImage = useState(nil :: EditableImage?)

	useEffect(function()
		local image = TextureUtils.createCheckerImage(config.checkerColorA, config.checkerColorB)
		setCheckerImage(image)

		return function()
			if image then
				image:Destroy()
			end
		end
	end, {})

	return createElement("Frame", {
		Active = true,
		BackgroundColor3 = tokens.Surface_100.Color3,
		BackgroundTransparency = tokens.Surface_100.Transparency,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 0),
		ref = props.viewRef,
	}, {
		flexItem = createElement("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Fill,
		}),
		corner = createElement("UICorner", {
			CornerRadius = tokens.Radius.Small,
		}),
		content = createElement("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = props.content:map(function(state: ContentState)
				return UDim2.fromOffset(state.position.X, state.position.Y)
			end),
			Size = props.content:map(function(state: ContentState)
				return UDim2.fromOffset(state.size.X, state.size.Y)
			end),
			ZIndex = 1,
		}, {
			backdrop = createElement("ImageLabel", {
				BackgroundColor3 = config.checkerColorA,
				BorderSizePixel = 0,
				ImageContent = contentOf(checkerImage),
				Interactable = false,
				ResampleMode = Enum.ResamplerMode.Pixelated,
				ScaleType = Enum.ScaleType.Tile,
				Size = UDim2.fromScale(1, 1),
				TileSize = UDim2.fromOffset(config.checkerCellSize * 2, config.checkerCellSize * 2),
				ZIndex = 0,
			}),
			texture = createElement("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Interactable = false,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			}, {
				texture1 = if props.textureImage
					then createElement("ImageLabel", {
						BackgroundTransparency = 1,
						ImageContent = contentOf(props.textureImage),
						ImageRectOffset = Vector2.zero,
						ImageRectSize = props.cellSize,
						Interactable = false,
						ResampleMode = props.content:map(function(state: ContentState)
							return if state.pixelated then Enum.ResamplerMode.Pixelated else Enum.ResamplerMode.Default
						end),
						Size = UDim2.fromScale(1, 1),
						ZIndex = 1,
					})
					else nil,
			}),
			wireframe = createElement("ImageLabel", {
				BackgroundTransparency = 1,
				ImageContent = contentOf(props.wireframeImage),
				ImageTransparency = config.wireframeOverlayTransparency,
				Interactable = false,
				Size = UDim2.fromScale(1, 1),
				Visible = props.wireframeVisible,
				ZIndex = 3,
			}),
			handles = createElement("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 4,
			}, props.children),
		}),
		cursor = createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Interactable = false,
			Position = props.cursor:map(function(state: CursorState)
				return UDim2.fromOffset(state.position.X, state.position.Y)
			end),
			Size = props.cursor:map(function(state: CursorState)
				return UDim2.fromOffset(state.diameter, state.diameter)
			end),
			Visible = props.cursor:map(function(state: CursorState)
				return state.visible
			end),
			ZIndex = 2,
		}, {
			stroke = createElement("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = tokens.Colors.White,
				Thickness = tokens.MainHandleBorderThickness,
			}),
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Circle,
			}),
		}),
		resizeGrip = createElement("TextButton", {
			AnchorPoint = Vector2.new(1, 1),
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = fonts.ToolTitleFont.Font,
			Position = UDim2.fromScale(1, 1),
			Size = tokens.SmallHandleSize,
			Text = "◢",
			TextColor3 = tokens.Colors.ContentDefault,
			TextSize = fonts.ToolTitleFont.FontSize,
			ZIndex = 3,
			ref = props.resizeGripRef,
		}),
	})
end)

return UVCanvasView

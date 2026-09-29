local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local React = require(ReplicatedStorage.Packages.React)

local Button = require("../Components/Button")
local EditHandle = require("../Components/EditHandle")
local IconButton = require("../Components/IconButton")
local SegmentedControl = require("../Components/SegmentedControl")
local SessionGate = require("./Creation/SessionGate")
local ToggleButton = require("../Components/ToggleButton")
local UVCanvasView = require("../Components/UVCanvasView")
local useAtom = require("../Hooks/useAtom")
local useAtomBinding = require("../Hooks/useAtomBinding")
local useCreationSession = require("../Hooks/useCreationSession")
local useScreenGui = require("../Hooks/useScreenGui")
local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local useEffect = React.useEffect
local useRef = React.useRef

export type CreationCanvasProps = {
	playerGui: ScreenGui,
}

local function Canvas(props: CreationCanvasProps)
	local theme = useTheme()
	local tokens = theme.tokens

	local session = useCreationSession()
	local canvas = session.panels.canvas
	local screen = useAtom(session.screen)
	local mode = useAtom(canvas.mode)
	local stacks = useAtom(canvas.stacks)
	local selectedStack = useAtom(canvas.selectedStack)
	local textureImage = useAtom(canvas.textureImage)
	local cellSize = useAtom(canvas.cellSize)
	local wireframeImage = useAtom(canvas.wireframeImage)
	local wireframeVisible = useAtom(canvas.wireframeVisible)
	local window = useAtomBinding(canvas.window)
	local content = useAtomBinding(canvas.content)
	local cursor = useAtomBinding(canvas.cursor)
	local stickerHandle = useAtomBinding(canvas.stickerHandle)

	local containerRef = useRef(nil :: Frame?)
	local viewRef = useRef(nil :: Frame?)
	local resizeGripRef = useRef(nil :: TextButton?)
	local rotateRef = useRef(nil :: GuiObject?)
	local scaleRef = useRef(nil :: GuiObject?)

	useScreenGui(props.playerGui, {
		DisplayOrder = 5,
		Enabled = screen == "edit",
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
	})

	useEffect(function()
		canvas:attach({
			container = containerRef.current,
			viewFrame = viewRef.current,
			resizeGrip = resizeGripRef.current,
			rotateHandle = rotateRef.current,
			scaleHandle = scaleRef.current,
		})

		return function()
			canvas:attach(nil)
		end
	end, { canvas })

	local stackNames = {}
	local selectedStackIndex = 1
	local textureInfo = session.modelInfo:getTextureInfo()
	for index, meshPart in stacks do
		stackNames[index] = meshPart.Name
		if selectedStack and textureInfo:meshPartsShareLayer(meshPart, selectedStack) then
			selectedStackIndex = index
		end
	end

	return createElement("Frame", {
		Active = true,
		BackgroundColor3 = tokens.Surface_0.Color3,
		BackgroundTransparency = tokens.Surface_0.Transparency,
		BorderSizePixel = 0,
		Position = window:map(function(rect)
			return UDim2.fromOffset(rect.position.X, rect.position.Y)
		end),
		Size = window:map(function(rect)
			return UDim2.fromOffset(rect.size.X, rect.size.Y)
		end),
		Visible = mode ~= nil,
		ref = containerRef,
	}, {
		padding = createElement("UIPadding", {
			PaddingBottom = tokens.Padding.Small,
			PaddingLeft = tokens.Padding.Small,
			PaddingRight = tokens.Padding.Small,
			PaddingTop = tokens.Padding.Small,
		}),
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = tokens.Padding.Small,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		corner = createElement("UICorner", {
			CornerRadius = tokens.Radius.Medium,
		}),
		header = createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
		}, {
			listLayout = createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
				Padding = tokens.Padding.Medium,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			wireframeToggle = createElement(ToggleButton, {
				alignLeft = true,
				initialOn = true,
				label = CreationStrings.uvWireframeToggle,
				layoutOrder = 1,
				onToggle = function(isOn: boolean)
					canvas:setWireframeVisible(isOn)
				end,
			}),
			stackSelector = if #stacks > 0
				then createElement(SegmentedControl, {
					options = stackNames,
					selectedIndex = selectedStackIndex,
					onSelect = function(index: number)
						canvas:selectLayerStack(stacks[index])
					end,
					native = { LayoutOrder = 2 },
				})
				else nil,
			resetButton = createElement(Button, {
				text = CreationStrings.uvCanvasResetView,
				onActivated = function()
					canvas:resetView()
				end,
				native = {
					AutomaticSize = Enum.AutomaticSize.X,
					LayoutOrder = 3,
				},
			}),
			closeButton = createElement(IconButton, {
				icon = CreationIcons.icons.XButton,
				iconSize = tokens.IconSize.Large,
				onActivated = function()
					canvas:requestClose()
				end,
				native = {
					BackgroundTransparency = 1,
					LayoutOrder = 4,
					Size = tokens.IconButtonSize,
				},
			}),
		}),
		view = createElement(UVCanvasView, {
			cellSize = cellSize,
			content = content,
			cursor = cursor,
			layoutOrder = 2,
			resizeGripRef = resizeGripRef,
			textureImage = textureImage,
			viewRef = viewRef,
			wireframeImage = wireframeImage,
			wireframeVisible = wireframeVisible,
		}, {
			stickerHandle = createElement(EditHandle, {
				handle = stickerHandle,
				moveInteractable = false,
				rotateRef = rotateRef,
				scaleRef = scaleRef,
			}),
		}),
	})
end

--[=[
	@class CreationCanvas
	@client

	The 2D canvas window: a header with the wireframe toggle, layer-stack picker, fit and close
	buttons over the texture view. Its behaviour, from gestures to window layout, belongs to
	[UVCanvas]; this view renders its atoms and hands it the instances to read input from.
]=]
local function CreationCanvas(props: CreationCanvasProps)
	return createElement(SessionGate, nil, {
		canvas = createElement(Canvas, props),
	})
end

return CreationCanvas

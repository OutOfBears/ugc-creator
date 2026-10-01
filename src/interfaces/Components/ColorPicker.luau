local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local GuiUtil = require(ReplicatedStorage.Shared.Modules.Utils.GuiUtil)
local React = require(ReplicatedStorage.Packages.React)

local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo
local useBinding = React.useBinding
local useRef = React.useRef

type Pick = {
	h: number,
	s: number,
	v: number,
	opacity: number,
}

export type ColorPickerProps = {
	onColorChange: (color: Color3, isFinalInput: boolean) -> (),
	onOpacityChange: ((opacity: number) -> ())?,
}

local function colorOf(pick: Pick): Color3
	return Color3.fromHSV(pick.h, pick.s, pick.v)
end

--[=[
	@class ColorPicker
	@client

	A saturation/value field, hue bar and opacity bar. It owns the picked color; `onColorChange`
	fires throughout a drag with `isFinalInput` true on release, and `onOpacityChange` when the
	opacity bar moves.
]=]
local ColorPicker = memo(function(props: ColorPickerProps)
	local theme = useTheme()
	local tokens = theme.tokens

	local default = CreationConfig.defaultColorPickerColor
	local current = useRef({ h = default.h, s = default.s, v = default.v, opacity = 1 } :: Pick)
	local pick, setPick = useBinding(current.current :: Pick)

	local function dragHandlers(apply: (pick: Pick, scale: Vector2) -> ())
		local function onDrag(detector: UIDragDetector, dragPosition: Vector2, isFinalInput: boolean)
			local nextPick = table.clone(current.current :: Pick)
			apply(nextPick, GuiUtil.getDragScale(detector.Parent :: GuiObject, dragPosition))

			current.current = nextPick
			setPick(nextPick)
			props.onColorChange(colorOf(nextPick), isFinalInput)
		end

		return {
			ResponseStyle = Enum.UIDragDetectorResponseStyle.CustomScale,
			[React.Event.DragStart] = function(detector, dragPosition)
				onDrag(detector, dragPosition, false)
			end,
			[React.Event.DragContinue] = function(detector, dragPosition)
				onDrag(detector, dragPosition, false)
			end,
			[React.Event.DragEnd] = function(detector, dragPosition)
				onDrag(detector, dragPosition, true)
			end,
		}
	end

	local function colorDot(position: any, color: any, transparency: any?)
		return createElement("Frame", {
			AnchorPoint = tokens.CenterAnchor,
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			Position = position,
			-- A non-zero rotation opts the dot out of the ancestor scrolling frame's ClipsDescendants.
			Rotation = 90,
			Size = tokens.ColorDotSize,
			ZIndex = 100,
		}, {
			stroke = createElement("UIStroke", {
				Color = tokens.System_Contrast.Color3,
				Thickness = tokens.ColorDotStrokeThickness,
				Transparency = tokens.System_Contrast.Transparency,
			}),
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Circle,
			}),
		})
	end

	local function gradientFill(color: Color3, zIndex: number, gradient: { [string]: any })
		return createElement("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = zIndex,
		}, {
			gradient = createElement("UIGradient", gradient),
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Small,
			}),
		})
	end

	local pickedColor = pick:map(colorOf)
	local hueColor = pick:map(function(value: Pick)
		return Color3.fromHSV(value.h, 1, 1)
	end)

	return createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
	}, {
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = if GuiService:IsTenFootInterface() then tokens.Padding.XXLarge else tokens.Padding.Small,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		satValPicker = createElement("Frame", {
			BackgroundColor3 = hueColor,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Size = tokens.SatValPickerSize,
		}, {
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Small,
			}),
			satGradient = gradientFill(tokens.Colors.White, 1, {
				Transparency = NumberSequence.new(0, 1),
			}),
			valGradient = gradientFill(tokens.Colors.Black, 2, {
				Rotation = 90,
				Transparency = NumberSequence.new(1, 0),
			}),
			colorDot = colorDot(
				pick:map(function(value: Pick)
					return UDim2.fromScale(value.s, 1 - value.v)
				end),
				pickedColor
			),
			dragDetector = createElement(
				"UIDragDetector",
				dragHandlers(function(nextPick: Pick, scale: Vector2)
					nextPick.s = scale.X
					nextPick.v = 1 - scale.Y
				end)
			),
		}),
		huePicker = createElement("Frame", {
			BackgroundColor3 = tokens.Colors.White,
			BorderSizePixel = 0,
			LayoutOrder = 2,
			Size = tokens.HueSliderSize,
		}, {
			gradient = createElement("UIGradient", {
				Color = tokens.Colors.RainbowGradient,
			}),
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Circle,
			}),
			colorDot = colorDot(
				pick:map(function(value: Pick)
					return UDim2.fromScale(value.h, 0.5)
				end),
				hueColor
			),
			dragDetector = createElement(
				"UIDragDetector",
				dragHandlers(function(nextPick: Pick, scale: Vector2)
					nextPick.h = scale.X
				end)
			),
		}),
		opacityPicker = createElement("ImageLabel", {
			BackgroundTransparency = 1,
			Image = CreationIcons.uiImages.OpacityPicker,
			LayoutOrder = 3,
			Size = tokens.HueSliderSize,
		}, {
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Circle,
			}),
			opacityOverlay = createElement("Frame", {
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
			}, {
				corner = createElement("UICorner", {
					CornerRadius = tokens.Radius.Circle,
				}),
				gradient = createElement("UIGradient", {
					Color = pickedColor:map(function(color: Color3)
						return ColorSequence.new(color)
					end),
					Transparency = NumberSequence.new(1, 0),
				}),
			}),
			colorDot = colorDot(
				pick:map(function(value: Pick)
					return UDim2.fromScale(value.opacity, 0.5)
				end),
				pickedColor,
				pick:map(function(value: Pick)
					return 1 - value.opacity
				end)
			),
			dragDetector = createElement(
				"UIDragDetector",
				dragHandlers(function(nextPick: Pick, scale: Vector2)
					nextPick.opacity = scale.X
					if props.onOpacityChange then
						props.onOpacityChange(scale.X)
					end
				end)
			),
		}),
	})
end)

return ColorPicker

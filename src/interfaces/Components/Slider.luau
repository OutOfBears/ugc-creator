local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiUtil = require(ReplicatedStorage.Shared.Modules.Utils.GuiUtil)
local React = require(ReplicatedStorage.Packages.React)

local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo
local useBinding = React.useBinding

export type SliderProps = {
	defaultValue: number,
	onChange: (value: number, isFinalInput: boolean) -> (),
}

--[=[
	@class Slider
	@client

	A 0-1 slider for sizes and spacing. It owns its value; `onChange` fires on every drag step with
	`isFinalInput` true on release. The input area is taller than the visible bar so it stays easy
	to grab on touch.
]=]
local Slider = memo(function(props: SliderProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local value, setValue = useBinding(props.defaultValue)

	local function onDrag(detector: UIDragDetector, dragPosition: Vector2, isFinalInput: boolean)
		local newValue = GuiUtil.getDragScale(detector.Parent :: GuiObject, dragPosition).X
		setValue(newValue)
		props.onChange(newValue, isFinalInput)
	end

	return createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
	}, {
		padding = createElement("UIPadding", {
			PaddingBottom = tokens.Padding.Medium,
			PaddingTop = tokens.Padding.Medium,
		}),
		sliderInput = createElement("TextButton", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = tokens.SliderInputSize,
			Text = "",
		}, {
			dragDetector = createElement("UIDragDetector", {
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
			}),
		}),
		sliderBar = createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = tokens.Shift_300.Color3,
			BackgroundTransparency = tokens.Shift_300.Transparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0.5),
			Size = tokens.SliderBarSize,
		}, {
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Circle,
			}),
			barProgress = createElement("Frame", {
				BackgroundColor3 = tokens.System_Contrast.Color3,
				BackgroundTransparency = tokens.System_Contrast.Transparency,
				BorderSizePixel = 0,
				Size = value:map(function(current: number)
					return UDim2.fromScale(current, 1)
				end),
			}, {
				corner = createElement("UICorner", {
					CornerRadius = tokens.Radius.Circle,
				}),
				sliderHandle = createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = tokens.System_Contrast.Color3,
					BackgroundTransparency = tokens.System_Contrast.Transparency,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(1, 0.5),
					-- A non-zero rotation opts the handle out of the ancestor scrolling frame's ClipsDescendants.
					Rotation = 90,
					Size = tokens.SliderHandleSize,
				}, {
					corner = createElement("UICorner", {
						CornerRadius = tokens.Radius.Circle,
					}),
				}),
			}),
		}),
	})
end)

return Slider

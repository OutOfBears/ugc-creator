local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local React = require(ReplicatedStorage.Packages.React)

local IconButton = require("./IconButton")
local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo

export type HandleState = {
	visible: boolean,
	offset: Vector2,
	scale: number,
	rotation: number,
}

export type EditHandleProps = {
	handle: React.Binding<HandleState>,
	moveInteractable: boolean?,
	rotateRef: { current: GuiObject? }?,
	scaleRef: { current: GuiObject? }?,
}

--[=[
	@class EditHandle
	@client

	The ring used to move, rotate and resize stickers and add-ons, with rotate and scale knobs on its
	edge. It only draws itself from the `handle` binding; the owner reads its knobs through the refs
	to drive the drag.
]=]
local EditHandle = memo(function(props: EditHandleProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local handle = props.handle

	local function knobPosition(degrees: number)
		return handle:map(function(state: HandleState)
			local radius = tokens.MainHandleDefaultRadius * state.scale / 2
			local radians = math.rad(degrees)
			local position = Vector2.new(math.cos(radians), -math.sin(radians)) * radius + Vector2.new(radius, radius)

			return UDim2.fromOffset(position.X, position.Y)
		end)
	end

	local function knob(icon: string, degrees: number, ref: { current: GuiObject? }?)
		return createElement(IconButton, {
			icon = icon,
			iconSize = tokens.SmallHandleIconSize,
			native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = tokens.Colors.White,
				Position = knobPosition(degrees),
				Size = tokens.SmallHandleSize,
				ref = ref,
			},
		}, {
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Circle,
			}),
		})
	end

	return createElement("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Interactable = props.moveInteractable ~= false,
		Position = handle:map(function(state: HandleState)
			return UDim2.fromOffset(state.offset.X, state.offset.Y)
		end),
		Rotation = handle:map(function(state: HandleState)
			return state.rotation
		end),
		Size = handle:map(function(state: HandleState)
			local diameter = tokens.MainHandleDefaultRadius * state.scale
			return UDim2.fromOffset(diameter, diameter)
		end),
		Text = "",
		Visible = handle:map(function(state: HandleState)
			return state.visible
		end),
	}, {
		stroke = createElement("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = tokens.Colors.White,
			Thickness = tokens.MainHandleBorderThickness,
			Transparency = 0,
		}),
		corner = createElement("UICorner", {
			CornerRadius = tokens.Radius.Circle,
		}),
		rotateHandle = knob(CreationIcons.icons.Rotate, tokens.RotateHandlePosDegrees, props.rotateRef),
		scaleHandle = knob(CreationIcons.icons.Scale, tokens.ScaleHandlePosDegrees, props.scaleRef),
	})
end)

return EditHandle

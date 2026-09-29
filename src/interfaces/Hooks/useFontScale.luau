local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local ClientAtoms = require(ReplicatedStorage.Client.Modules.ClientAtoms)
local React = require(ReplicatedStorage.Packages.React)

local useEffect = React.useEffect
local useState = React.useState

local BASE_FONT_SIZE = 16
local BASE_HEIGHT = 1080

type Ref<T> = { current: T? }
type Axis = "X" | "Y"
type ScaleFn = (units: number) -> number

local scaleCache: { [number]: ScaleFn } = {}

local function getScale(dimension: number): ScaleFn
	local cached = scaleCache[dimension]
	if cached then
		return cached
	end

	local multiplier = dimension / BASE_HEIGHT * BASE_FONT_SIZE
	local fn = function(units: number): number
		return math.round(units * multiplier)
	end

	scaleCache[dimension] = fn
	return fn
end

local function pick(size: Vector2, axis: Axis): number
	return if axis == "X" then size.X else size.Y
end

--[=[
	@class Hooks
	@client

	React hooks for interface code in `src/interfaces/Hooks`.
]=]

--[=[
	@function useFontScale
	@within Hooks

	Returns two functions for scaling font sizes based on the viewport and an optional parent GUI object's size. The functions take a number of "units" and return a scaled font size in pixels.

	@param parentRef Ref<GuiObject>? -- An optional React ref to a GuiObject. If provided, the second scale function will scale based on this object's size instead of the viewport.
	@param axis Axis? -- Optional axis ("X" or "Y") to scale by. Defaults to "Y".

	@return (ScaleFn, ScaleFn) -- A tuple containing two scale functions: (viewportScaleFn, parentScaleFn) (rem and em)
]=]
local function useFontScale(parentRef: Ref<GuiObject>?, axis: Axis?): (ScaleFn, ScaleFn)
	local resolvedAxis: Axis = axis or "Y"

	local viewportDimension, setViewportDimension = useState(function()
		return pick(ClientAtoms.viewportSize(), resolvedAxis)
	end)

	local parentDimension, setParentDimension = useState(function()
		local parent = parentRef and parentRef.current
		return if parent then pick(parent.AbsoluteSize, resolvedAxis) else 0
	end)

	useEffect(function()
		setViewportDimension(pick(ClientAtoms.viewportSize(), resolvedAxis))

		return Charm.subscribe(ClientAtoms.viewportSize, function(size: Vector2)
			setViewportDimension(pick(size, resolvedAxis))
		end)
	end, { resolvedAxis } :: { any })

	useEffect(function()
		if not parentRef then
			return
		end

		local parent = parentRef.current
		if not parent then
			return
		end

		setParentDimension(pick(parent.AbsoluteSize, resolvedAxis))
		local connection = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			setParentDimension(pick(parent.AbsoluteSize, resolvedAxis))
		end)

		return function()
			connection:Disconnect()
		end
	end, { parentRef, resolvedAxis } :: { any })

	return getScale(viewportDimension), getScale(parentDimension)
end

return useFontScale

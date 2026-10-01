local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local useBinding = React.useBinding
local useEffect = React.useEffect

local mouse = Players.LocalPlayer:GetMouse()

--[=[
	@function useMousePosition
	@within Hooks

	Tracks the mouse position as a React binding, updating on mouse movement.

	@return React.Binding<UDim2> -- a binding of the cursor position as a `UDim2` offset
]=]
local function useMousePosition()
	local position, setPosition = useBinding(UDim2.fromOffset(mouse.X, mouse.Y))

	useEffect(function()
		local conn = mouse.Move:Connect(function()
			setPosition(UDim2.fromOffset(mouse.X, mouse.Y))
		end)

		return function()
			conn:Disconnect()
		end
	end, {})

	return position
end

return useMousePosition

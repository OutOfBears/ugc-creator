local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local useLayoutEffect = React.useLayoutEffect

--[=[
	@function useScreenGui
	@within Hooks

	Applies a view's ScreenGui settings (display order, insets, enabled) to the ScreenGui
	`UIController` mounted it in, re-applying whenever they change.

	@param screenGui ScreenGui -- the view's `playerGui` prop
	@param properties { [string]: any } -- ScreenGui properties to set
]=]
local function useScreenGui(screenGui: ScreenGui, properties: { [string]: any })
	local dependencies: { any } = { screenGui }
	for _, value in properties do
		table.insert(dependencies, value)
	end

	useLayoutEffect(function()
		for property, value in properties do
			(screenGui :: any)[property] = value
		end
	end, dependencies)
end

return useScreenGui

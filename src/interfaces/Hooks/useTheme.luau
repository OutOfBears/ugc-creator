local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local ThemeContext = require("../Contexts/ThemeContext")

local useContext = React.useContext

--[=[
	@function useTheme
	@within Hooks

	@return Theme -- the design tokens and the active mobile or desktop layout tokens
]=]
local function useTheme(): ThemeContext.Theme
	return useContext(ThemeContext.Context)
end

return useTheme

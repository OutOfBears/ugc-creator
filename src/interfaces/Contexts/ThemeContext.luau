local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StyleLayouts = require(ReplicatedStorage.Shared.Data.StyleLayouts)
local StyleTokens = require(ReplicatedStorage.Shared.Data.StyleTokens)

local createContext = React.createContext
local createElement = React.createElement

export type Theme = {
	tokens: StyleTokens.StyleTable,
	fonts: StyleTokens.FontTable,
	layout: StyleLayouts.StyleLayout,
	isMobile: boolean,
}

local DESKTOP: Theme = {
	tokens = StyleTokens.style,
	fonts = StyleTokens.fonts,
	layout = StyleLayouts.desktop,
	isMobile = false,
}

local MOBILE: Theme = {
	tokens = StyleTokens.style,
	fonts = StyleTokens.fonts,
	layout = StyleLayouts.mobile,
	isMobile = true,
}

local ThemeContext = createContext(DESKTOP)

export type ThemeProviderProps = {
	isMobile: boolean,
	children: React.ReactNode,
}

--[=[
	@within Hooks

	Provides the creation UI's design tokens and the mobile or desktop layout tokens to a subtree.
	The value only changes when `isMobile` flips.
]=]
local function ThemeProvider(props: ThemeProviderProps)
	return createElement(ThemeContext.Provider, {
		value = if props.isMobile then MOBILE else DESKTOP,
	}, props.children)
end

return {
	Context = ThemeContext,
	Provider = ThemeProvider,
	default = DESKTOP,
}

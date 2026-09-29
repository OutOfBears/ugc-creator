local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local createContext = React.createContext
local createElement = React.createElement

local CreationSessionContext = createContext(nil :: any)

export type CreationSessionProviderProps = {
	session: any,
	children: React.ReactNode,
}

--[=[
	@within Hooks

	Provides the open [CreationSession] — its tools and their state atoms — to a subtree, so
	panels reach a tool without it being threaded through every layer.
]=]
local function CreationSessionProvider(props: CreationSessionProviderProps)
	return createElement(CreationSessionContext.Provider, {
		value = props.session,
	}, props.children)
end

return {
	Context = CreationSessionContext,
	Provider = CreationSessionProvider,
	default = nil,
}

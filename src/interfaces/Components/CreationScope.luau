local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local CreationSessionContext = require("../Contexts/CreationSessionContext")
local ThemeContext = require("../Contexts/ThemeContext")

local createElement = React.createElement
local memo = React.memo

export type CreationScopeProps = {
	session: any,
	isMobile: boolean,
	children: React.ReactNode,
}

--[=[
	@class CreationScope
	@client

	Wraps a creation view's subtree in the theme and the open session. Views render it keyed by
	`session.id` so opening a new session remounts the subtree instead of reusing stale state.
]=]
local CreationScope = memo(function(props: CreationScopeProps)
	return createElement(ThemeContext.Provider, {
		isMobile = props.isMobile,
	}, {
		session = createElement(CreationSessionContext.Provider, {
			session = props.session,
		}, props.children),
	})
end)

return CreationScope

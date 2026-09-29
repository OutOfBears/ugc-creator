local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientAtoms = require(ReplicatedStorage.Client.Modules.ClientAtoms)
local React = require(ReplicatedStorage.Packages.React)

local CreationScope = require("../../Components/CreationScope")
local useAtom = require("../../Hooks/useAtom")

local createElement = React.createElement

export type SessionGateProps = {
	children: React.ReactNode?,
}

--[=[
	@class SessionGate
	@client

	Renders its children only while an editor session is open, inside a [CreationScope] keyed by
	the session so a new session remounts them fresh.
]=]
local function SessionGate(props: SessionGateProps)
	local session = useAtom(ClientAtoms.creationSession)
	local isMobile = useAtom(ClientAtoms.isMobile)

	if not session then
		return nil
	end

	return createElement(CreationScope, {
		key = `session{session.id}`,
		session = session,
		isMobile = isMobile,
	}, props.children)
end

return SessionGate

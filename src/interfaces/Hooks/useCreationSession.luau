local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local CreationSessionContext = require("../Contexts/CreationSessionContext")

local useContext = React.useContext

--[=[
	@function useCreationSession
	@within Hooks

	@return CreationSession -- the open session; only valid under a [CreationScope]
]=]
local function useCreationSession(): any
	return useContext(CreationSessionContext.Context)
end

return useCreationSession

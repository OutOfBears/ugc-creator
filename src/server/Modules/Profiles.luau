local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Behaviors = require(ReplicatedStorage.Shared.Modules.Utils.Behaviors)
local ServerPlayerProfile = require(ServerScriptService.Server.Behaviors.ServerPlayerProfile)

--[=[
	@class Profiles
	@server

	Thin accessor for the per-player `ServerPlayerProfile` behavior, so tycoon code
	reads and writes persistent data without re-deriving the behavior lookup.
]=]

local READY_TIMEOUT = 10

--[=[
	@within Profiles
	@param player Player
	@return ServerPlayerProfile.Profile? -- the player's profile behavior, or nil
]=]
local function get(player: Player): ServerPlayerProfile.Profile?
	return Behaviors.getBehavior(player, ServerPlayerProfile)
end

--[=[
	@within Profiles
	@yields
	@param player Player
	@return ServerPlayerProfile.Profile? -- the profile once its session has loaded

	Waits for the profile behavior to attach and its session to load, bounded by a
	timeout so a failed load can't hang the caller.
]=]
local function waitFor(player: Player): ServerPlayerProfile.Profile?
	local ok, profile = pcall(function()
		return Behaviors.waitForBehavior(player, ServerPlayerProfile):expect()
	end)
	if not ok or not profile then
		return nil
	end

	local elapsed = 0
	while not profile.ready and elapsed < READY_TIMEOUT and player.Parent do
		elapsed += task.wait()
	end

	return profile
end

return {
	get = get,
	waitFor = waitFor,
}

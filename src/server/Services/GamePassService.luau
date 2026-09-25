local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Behaviors = require(ReplicatedStorage.Shared.Modules.Utils.Behaviors)
local GamePasses = require(ReplicatedStorage.Shared.Data.GamePasses)
local Types = require(ReplicatedStorage.Shared.Types)

local ServerPlayerProfile = require("../Behaviors/ServerPlayerProfile")

type Profile = ServerPlayerProfile.Profile

--[=[
	@class GamePassService
	@server

	Tracks each player's owned gamepasses. Effective ownership is the union of what the player
	owns on Roblox (checked on join with `UserOwnsGamePassAsync`, which also reports the game
	creator as owning every pass) and any pass granted on the server (a real purchase or the
	`giveGamepass` command).

	Only **grants** are written to the persistent [ServerPlayerProfile] `gamepasses` field — live
	Roblox ownership is deliberately not persisted, so a transient result (e.g. the creator, or a
	later refund) never gets baked into the save. The effective set is replicated separately under
	the transient `gamepassesOwned` key, which the client reads through `useGamepassOwnership`.
]=]
local GamePassService = {} :: Types.Service & {
	owns: (player: Player, passId: number) -> boolean,
	grant: (player: Player, passId: number) -> boolean,
}

local grants: { [Player]: { [number]: boolean } } = {}
local owned: { [Player]: { [number]: boolean } } = {}

local function toSet(list: { number }?): { [number]: boolean }
	local set = {}
	if list then
		for _, id in list do
			if typeof(id) == "number" and id > 0 then
				set[id] = true
			end
		end
	end

	return set
end

local function toList(set: { [number]: boolean }?): { number }
	local list = {}
	if set then
		for id, isOwned in set do
			if isOwned then
				table.insert(list, id)
			end
		end
	end
	table.sort(list)

	return list
end

local function distinctPassIds(): { number }
	local seen: { [number]: boolean } = {}
	local ids = {}
	for _, passId in GamePasses do
		if passId > 0 and not seen[passId] then
			seen[passId] = true
			table.insert(ids, passId)
		end
	end

	return ids
end

local function replicateOwned(profile: Profile, player: Player)
	profile.replicator:Set("gamepassesOwned", toList(owned[player]))
end

local function syncPlayer(player: Player)
	Behaviors.waitForBehavior(player, ServerPlayerProfile)
		:andThen(function(profile: Profile)
			local function apply()
				local grantSet = toSet(profile:get("gamepasses"))
				grants[player] = grantSet
				owned[player] = table.clone(grantSet)
				replicateOwned(profile, player)

				-- The game creator owns every pass they made, so `UserOwnsGamePassAsync` reports
				-- all of them in Studio; skip the merge there and let `giveGamepass` drive testing
				-- (real purchase prompts can't complete in Studio anyway).
				if RunService:IsStudio() then
					return
				end

				task.spawn(function()
					for _, passId in distinctPassIds() do
						local ok, isOwned = pcall(function()
							return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
						end)
						if ok and isOwned and owned[player] then
							owned[player][passId] = true
						end
					end

					if owned[player] then
						replicateOwned(profile, player)
					end
				end)
			end

			if profile.ready then
				apply()
			else
				profile.loaded:Once(apply)
			end
		end)
		:catch(function() end)
end

--[=[
	@within GamePassService
	@param player Player -- the owner to check
	@param passId number -- the gamepass id (0 for an unconfigured pass)
	@return boolean -- true once the player is known to own the pass this session
]=]
function GamePassService.owns(player: Player, passId: number): boolean
	if passId <= 0 then
		return false
	end

	local set = owned[player]
	return set ~= nil and set[passId] == true
end

--[=[
	@within GamePassService
	@param player Player -- the player to grant the pass to
	@param passId number -- the gamepass id to grant
	@return boolean -- true once the grant is recorded (persisted and replicated)

	Records ownership without a Roblox purchase — used by a completed purchase prompt and the
	`giveGamepass` command. Persists to the save (grants only) and updates the replicated set.
]=]
function GamePassService.grant(player: Player, passId: number): boolean
	if passId <= 0 then
		return false
	end

	local grantSet = grants[player] or {}
	grantSet[passId] = true
	grants[player] = grantSet

	local ownedSet = owned[player] or {}
	ownedSet[passId] = true
	owned[player] = ownedSet

	Behaviors.waitForBehavior(player, ServerPlayerProfile)
		:andThen(function(profile: Profile)
			profile:set("gamepasses", toList(grants[player]))
			replicateOwned(profile, player)
		end)
		:catch(function() end)

	return true
end

function GamePassService.onRun()
	Players.PlayerAdded:Connect(syncPlayer)
	Players.PlayerRemoving:Connect(function(player)
		grants[player] = nil
		owned[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if wasPurchased then
			GamePassService.grant(player, passId)
		end
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(syncPlayer, player)
	end
end

return GamePassService

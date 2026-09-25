--[=[
	@class KonsoleService
	@server

	Hosts the Konsole command bridge and registers the game's debug commands.
	Client-only commands live in `Commands/Client` and are reparented to
	ReplicatedStorage so KonsoleController can define them locally.
]=]

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Konsole = require(ReplicatedStorage.Packages.Konsole)
local Promise = require(ReplicatedStorage.Shared.Modules.Promise)
local Types = require(ReplicatedStorage.Shared.Types)

local KonsoleService = {} :: Types.Service

local SUPER_USERS = Constants.SUPER_USERS
local GROUP_RANKS = Constants.GROUP_RANKS
local GROUP_ID = Constants.GROUP_ID

local function getGroupRanks(player: Player)
	local userId = player.UserId

	local promise = Promise.retryWithDelay(function()
		return Promise.new(function(resolve, reject)
			if player.Parent ~= Players then
				reject("player has left the game")
			end

			local success, resultOrErr = pcall(function()
				return GroupService:GetRolesInGroupAsync(userId, GROUP_ID)
			end)

			if success then
				resolve(resultOrErr :: Types.GroupRoles)
			else
				reject(resultOrErr :: string)
			end
		end)
	end, 10, 1)

	return promise
end

local function getHighestGroupRank(group: Types.GroupRoles): number?
	if not group.IsMember then
		return nil
	end

	local rank = nil

	for _, role in group.Roles do
		local relatedRole = GROUP_RANKS[role.Name]
		if not relatedRole then
			continue
		end

		if not rank then
			rank = relatedRole
		end

		rank = math.max(relatedRole, rank)
	end

	return rank
end

function KonsoleService.onInit()
	Players.PlayerAdded:Connect(function(player: Player)
		local rankId = nil

		if GROUP_ID ~= 0 then
			local groupRanks = getGroupRanks(player):expect()
			rankId = getHighestGroupRank(groupRanks)
		end

		if SUPER_USERS[player.UserId] then
			rankId = math.huge
		end

		if rankId then
			Konsole.Ranks.set(player.UserId, rankId)
		end

		if Konsole.Ranks.allows(player, "admin") then
			player:SetAttribute("isDev", true)
		end
	end)

	local clientCommands = Create("Folder", {
		Name = "KonsoleClientCommands",
	})

	for _, command in script.Commands:GetChildren() do
		if not command:IsA("ModuleScript") then
			continue
		end

		local name = command.Name
		if name:match("Client$") then
			command.Parent = clientCommands
		end

		Konsole.define(require(command) :: Konsole.Definition)
	end

	clientCommands.Parent = ReplicatedStorage
	Konsole.host()
end

return KonsoleService

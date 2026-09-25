local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

--[=[
	@class PlayerService
	@server

	Attaches player behaviors and publishes character deaths with optional
	player kill attribution.
]=]
local PlayerService = {} :: Types.Service & {}

local function onCharacterAdded(_player: Player, character: Model)
	character:AddTag("Character")
end

local function onPlayerAdded(player: Player)
	player:AddTag("Player")
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

function PlayerService.onRun()
	Players.PlayerAdded:Connect(onPlayerAdded)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerService

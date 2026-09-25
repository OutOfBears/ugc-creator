local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttributeReplicator = require(ReplicatedStorage.Shared.Modules.AttributeReplicator)

export type MusicState = { track: string | number, startedAt: number }

export type GameState = {
	music: MusicState?,
}

local FOLDER_NAME = "GameState"

local defaults: GameState = {
	music = nil,
}

local folder = Instance.new("Folder")
folder.Name = FOLDER_NAME
folder.Parent = ReplicatedStorage.Replicators

local replicator = AttributeReplicator.new(folder, defaults)

--[=[
	@class GameStateReplicator
	@server

	Owns the single global game-state replicator, an [AttributeReplicator] on a `GameState`
	folder under `ReplicatedStorage.Replicators`. Services mutate shared game state through this
	typed surface rather than poking attributes directly; clients read it with the `useGameState`
	hook. Add fields here as global state grows.
]=]
local GameStateReplicator = {}

--[=[
	@within GameStateReplicator
	@param track string | number -- the now-playing music asset
	@param startedAt number -- absolute server time ([TimeUtils.now]) the track began, so clients seek to the elapsed position

	Publishes the synced now-playing track as one atomic field. Deliberately excluded from
	[GameStateReplicator.reset] so music plays on uninterrupted across resets.
]=]
function GameStateReplicator.setMusic(track: string | number, startedAt: number)
	replicator:Set("music", { track = track, startedAt = startedAt })
end

--[=[
	@within GameStateReplicator

	Restores every field to its default (used on soft reset).
]=]
function GameStateReplicator.reset() end

return GameStateReplicator

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AssetUtil = require(ReplicatedStorage.Shared.Modules.Utils.AssetUtil)
local MusicConfig = require(ReplicatedStorage.Shared.Data.MusicConfig)
local MusicPlaylist = require(ReplicatedStorage.Shared.Data.MusicPlaylist)
local TimeUtils = require(ReplicatedStorage.Shared.Modules.Utils.TimeUtils)
local Types = require(ReplicatedStorage.Shared.Types)

local GameStateReplicator = require("../Modules/GameStateReplicator")

--[=[
	@class MusicService
	@server

	Authoritative director for the synced background music. Shuffles the `MusicPlaylist`, then
	plays it one track at a time on the server clock, publishing the now-playing track and its
	start time through `GameStateReplicator.setMusic`. Every client's `MusicController` reads
	that replicated state and seeks to the elapsed position, so all players hear the same track
	together and a joining player picks it up mid-song.
]=]
local MusicService = {} :: Types.Service

local order: { number } = {}
local cursor = 0
local lengthCache: { [string | number]: number } = {}

local rng = Random.new()

local function reshuffle()
	local count = #MusicPlaylist
	order = table.create(count)
	for i = 1, count do
		order[i] = i
	end
	for i = count, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	cursor = 0
end

local function resolveLength(track: string | number): number
	local cached = lengthCache[track]
	if cached then
		return cached
	end

	local sound = Instance.new("Sound")
	sound.SoundId = AssetUtil.toContent(track) or ""
	sound.Parent = ServerStorage
	pcall(function()
		ContentProvider:PreloadAsync({ sound })
	end)

	local length = if sound.TimeLength > 0 then sound.TimeLength else MusicConfig.fallbackLength
	sound:Destroy()

	lengthCache[track] = length
	return length
end

local function run()
	reshuffle()

	while #MusicPlaylist > 0 do
		cursor += 1
		if cursor > #order then
			reshuffle()
			cursor = 1
		end

		local track = MusicPlaylist[order[cursor]]
		local length = resolveLength(track)

		GameStateReplicator.setMusic(track, TimeUtils.now())

		task.wait(length)
	end
end

function MusicService.onRun()
	task.spawn(run)
end

return MusicService

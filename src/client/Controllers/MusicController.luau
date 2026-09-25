local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetUtil = require(ReplicatedStorage.Shared.Modules.Utils.AssetUtil)
local AttributeReplicator = require(ReplicatedStorage.Shared.Modules.AttributeReplicator)
local AudioUtil = require(ReplicatedStorage.Shared.Modules.Utils.AudioUtil)
local MusicConfig = require(ReplicatedStorage.Shared.Data.MusicConfig)
local TimeUtils = require(ReplicatedStorage.Shared.Modules.Utils.TimeUtils)
local Types = require(ReplicatedStorage.Shared.Types)

--[=[
	@class MusicController
	@client

	Plays the background music the `MusicService` directs. The server owns the shuffle order and
	each track's start time, publishing them to the `GameState` replicator's `music` field. This
	watches that field and plays whatever it holds, seeking to the elapsed position
	(`now - startedAt`) so a mid-track joiner lines up with everyone else.
]=]
local MusicController = {} :: Types.Controller

type MusicState = { track: string | number, startedAt: number }

local currentHandle: AudioUtil.AudioHandle? = nil
local lastStartedAt: number? = nil

local function playMusic(music: MusicState?)
	if not music then
		return
	end

	local soundId = AssetUtil.toContent(music.track)
	if not soundId or lastStartedAt == music.startedAt then
		return
	end

	if currentHandle then
		currentHandle:stop()
		currentHandle = nil
	end

	local offset = math.max(0, TimeUtils.now() - music.startedAt)
	lastStartedAt = music.startedAt

	currentHandle = AudioUtil.play2D(soundId, {
		group = "Music",
		startTime = offset,
		fadeIn = MusicConfig.fadeSeconds,
		volume = MusicConfig.volume,
	})
end

function MusicController.onRun()
	local folder = ReplicatedStorage.Replicators:WaitForChild("GameState")
	local replicator = AttributeReplicator.waitForReplicator(folder):expect()

	replicator:GetStateChangedSignal("music"):Connect(playMusic)
	playMusic(replicator:Get("music"))
end

return MusicController

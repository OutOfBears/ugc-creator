-- AudioUtil: thin wrapper over Roblox's classic Sound system.
--
-- One-shot:
--     AudioUtil.play2D("rbxassetid://1234", { volume = 0.6, group = "SFX" })
--
-- Looping 3D sound (e.g. a campfire):
--     local h = AudioUtil.play3D("rbxassetid://fire", firePart, {
--         looping = true,
--         loopStart = 0.3, loopEnd = 5.2,
--         rollOffMinDistance = 4, rollOffMaxDistance = 60,
--         group = "Ambient",
--     })
--
-- Sidechain duck (music drops while a voice line plays):
--     local voice = AudioUtil.play2D("rbxassetid://voice", { group = "Voice" })
--     AudioUtil.duck("Music", voice)   -- auto-undoes when voice ends
--
-- Each play creates a Sound routed through a per-group SoundGroup, and destroys
-- it when the sound ends or handle:stop() is called.

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

export type MixGroup = "Master" | "Music" | "SFX" | "UI" | "Ambient" | "Voice"

export type PlayOptions = {
	-- playback
	volume: number?,
	playbackSpeed: number?,
	pitchVariation: number?,
	playbackVariation: number?,
	volumeVariation: number?,
	looping: boolean?,
	fadeIn: number?,
	fadeOut: number?,
	startTime: number?,
	loopStart: number?,
	loopEnd: number?,

	-- routing
	group: MixGroup?,

	-- 3D
	rollOffMinDistance: number?,
	rollOffMaxDistance: number?,
}

export type AudioHandle = {
	instance: Sound,
	finished: RBXScriptSignal,
	stop: (self: AudioHandle) -> (),
	fadeOut: (self: AudioHandle, duration: number) -> (),
	setVolume: (self: AudioHandle, volume: number) -> (),
	setPlaybackSpeed: (self: AudioHandle, speed: number) -> (),
	setLooping: (self: AudioHandle, looping: boolean) -> (),
	setLoopRegion: (self: AudioHandle, start: number?, finish: number?) -> (),
	setRollOff: (self: AudioHandle, minDistance: number, maxDistance: number) -> (),
}

export type DuckOptions = {
	threshold: number?,
	ratio: number?,
	attack: number?,
	release: number?,
	makeupGain: number?,
}

type SoundContext = {
	sound: Sound,
	tempAttachment: Attachment?,
	connections: { RBXScriptConnection },
	tweenThread: thread?,
	finishedEvent: BindableEvent,
}

-- ───── Constants ─────

local TWEEN_HZ = 30
local DEFAULT_GROUP: MixGroup = "SFX"
local ROOT_NAME = "AudioUtilRoot"
local DEFAULT_MIN_DISTANCE = 10
local DEFAULT_MAX_DISTANCE = 80

local rng = Random.new()
local activeSounds: { [Sound]: SoundContext } = {}
local soundGroups: { [string]: SoundGroup } = {}
local groupVolumes: { [string]: number } = {
	Master = 1,
	Music = 1,
	SFX = 1,
	UI = 1,
	Ambient = 1,
	Voice = 1,
}
local rootFolder: Folder? = nil

local function getRoot(): Folder
	if rootFolder and rootFolder.Parent then
		return rootFolder :: Folder
	end
	local existing = SoundService:FindFirstChild(ROOT_NAME)
	if existing and existing:IsA("Folder") then
		rootFolder = existing
	else
		local folder = Instance.new("Folder")
		folder.Name = ROOT_NAME
		folder.Parent = SoundService
		rootFolder = folder
	end
	return rootFolder :: Folder
end

local function getSoundGroup(name: MixGroup): SoundGroup
	local existing = soundGroups[name]
	if existing and existing.Parent then
		return existing
	end

	local group = Instance.new("SoundGroup")
	group.Name = `Group_{name}`
	group.Volume = groupVolumes[name] or 1
	group.Parent = getRoot()

	soundGroups[name] = group
	return group
end

local function resolveSoundGroup(source: any): SoundGroup?
	if typeof(source) == "Instance" then
		return if source:IsA("SoundGroup") then source else nil
	end
	if type(source) == "string" then
		return getSoundGroup(source :: MixGroup)
	end
	if type(source) == "table" and source.instance then
		return (source.instance :: Sound).SoundGroup
	end
	return nil
end

local function startVolumeTween(ctx: SoundContext, target: number, duration: number, onComplete: (() -> ())?)
	if ctx.tweenThread then
		task.cancel(ctx.tweenThread)
		ctx.tweenThread = nil
	end
	if duration <= 0 then
		ctx.sound.Volume = target
		if onComplete then
			onComplete()
		end
		return
	end

	local sound = ctx.sound
	local start = sound.Volume
	local elapsed = 0
	local step = 1 / TWEEN_HZ

	ctx.tweenThread = task.spawn(function()
		while elapsed < duration do
			task.wait(step)
			elapsed += step
			local alpha = math.min(elapsed / duration, 1)
			sound.Volume = start + (target - start) * alpha
		end

		sound.Volume = target
		ctx.tweenThread = nil

		if onComplete then
			onComplete()
		end
	end)
end

local function cleanup(sound: Sound)
	local ctx = activeSounds[sound]
	if not ctx then
		return
	end
	activeSounds[sound] = nil

	-- Fire before tearing anything down so listeners see a valid handle.
	ctx.finishedEvent:Fire()

	for _, conn in ctx.connections do
		conn:Disconnect()
	end
	if ctx.tweenThread then
		task.cancel(ctx.tweenThread)
	end

	sound:Stop()
	sound:Destroy()
	if ctx.tempAttachment then
		ctx.tempAttachment:Destroy()
	end
	ctx.finishedEvent:Destroy()
end

local function buildHandle(sound: Sound, ctx: SoundContext): AudioHandle
	local handle: AudioHandle
	handle = {
		instance = sound,
		finished = ctx.finishedEvent.Event,
		stop = function(_self)
			cleanup(sound)
		end,
		fadeOut = function(_self, duration)
			local current = activeSounds[sound]
			if not current then
				return
			end
			startVolumeTween(current, 0, duration, function()
				cleanup(sound)
			end)
		end,
		setVolume = function(_self, volume)
			sound.Volume = volume
		end,
		setPlaybackSpeed = function(_self, speed)
			sound.PlaybackSpeed = speed
		end,
		setLooping = function(_self, looping)
			sound.Looped = looping
		end,
		setLoopRegion = function(_self, start, finish)
			sound.PlaybackRegion = NumberRange.new(start or 0, finish or 0)
			sound.PlaybackRegionsEnabled = true
		end,
		setRollOff = function(_self, minDistance, maxDistance)
			sound.RollOffMinDistance = minDistance
			sound.RollOffMaxDistance = maxDistance
		end,
	}
	return handle
end

local function evaluateVariation(variation: number | NumberRange?): number
	local min, max
	if typeof(variation) == "NumberRange" then
		min = variation.Min
		max = variation.Max
	else
		min = -variation
		max = variation
	end

	return rng:NextNumber(min, max)
end

local function play(assetId: string | number, opts: PlayOptions?, attachTo: Instance?): AudioHandle
	local options: PlayOptions = opts or {}

	local sound = Instance.new("Sound")
	sound.SoundId = if typeof(assetId) == "number" then `rbxassetid://{assetId}` else assetId

	local baseVolume = options.volume or 1
	local baseSpeed = options.playbackSpeed or 1

	if options.volumeVariation then
		baseVolume += evaluateVariation(options.volumeVariation)
		baseVolume = math.max(baseVolume, 0)
	end
	if options.pitchVariation then
		sound.Pitch = 1 + evaluateVariation(options.pitchVariation)
	end
	if options.playbackVariation then
		baseSpeed += evaluateVariation(options.playbackVariation)
		baseSpeed = math.max(baseSpeed, 0.01)
	end

	sound.PlaybackSpeed = baseSpeed
	sound.Looped = options.looping or false
	if options.loopStart or options.loopEnd then
		sound.PlaybackRegion = NumberRange.new(options.loopStart or 0, options.loopEnd or 0)
		sound.PlaybackRegionsEnabled = true
	end

	local group: MixGroup = options.group or DEFAULT_GROUP
	sound.SoundGroup = getSoundGroup(group)

	local ctx: SoundContext = {
		sound = sound,
		tempAttachment = nil,
		connections = {},
		tweenThread = nil,
		finishedEvent = Instance.new("BindableEvent"),
	}

	if attachTo then
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound.RollOffMinDistance = options.rollOffMinDistance or DEFAULT_MIN_DISTANCE
		sound.RollOffMaxDistance = options.rollOffMaxDistance or DEFAULT_MAX_DISTANCE
		sound.Parent = attachTo
	else
		sound.Parent = getRoot()
	end

	activeSounds[sound] = ctx

	if not sound.Looped then
		table.insert(
			ctx.connections,
			sound.Ended:Connect(function()
				if options.fadeOut and options.fadeOut > 0 then
					startVolumeTween(ctx, 0, options.fadeOut, function()
						cleanup(sound)
					end)
				else
					cleanup(sound)
				end
			end)
		)
	end

	if options.fadeIn and options.fadeIn > 0 then
		sound.Volume = 0
		sound:Play()
		startVolumeTween(ctx, baseVolume, options.fadeIn, nil)
	else
		sound.Volume = baseVolume
		sound:Play()
	end

	if options.startTime then
		sound.TimePosition = options.startTime
	end

	return buildHandle(sound, ctx)
end

local AudioUtil = {}

function AudioUtil.play2D(assetId: string, opts: PlayOptions?): AudioHandle
	return play(assetId, opts, nil)
end

function AudioUtil.play3D(assetId: string, parent: Instance, opts: PlayOptions?): AudioHandle
	return play(assetId, opts, parent)
end

function AudioUtil.playAt(assetId: string, position: Vector3, opts: PlayOptions?): AudioHandle
	local attachment = Instance.new("Attachment")
	attachment.Name = "AudioUtilWorldPoint"
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain

	local handle = play(assetId, opts, attachment)
	local ctx = activeSounds[handle.instance]
	if ctx then
		ctx.tempAttachment = attachment
	end
	return handle
end

function AudioUtil.setGroupVolume(name: MixGroup, volume: number)
	groupVolumes[name] = volume
	getSoundGroup(name).Volume = volume
end

function AudioUtil.getGroupVolume(name: MixGroup): number
	return groupVolumes[name] or 1
end

function AudioUtil.muteGroup(name: MixGroup, muted: boolean)
	AudioUtil.setGroupVolume(name, muted and 0 or 1)
end

function AudioUtil.stopAll()
	for sound in activeSounds do
		cleanup(sound)
	end
end

-- Classic Sound uses the camera as the default listener, so there is nothing to
-- install; kept for API compatibility with the previous implementation.
function AudioUtil.ensureListener(_target: Instance?) end

function AudioUtil.preload(assetId: string | number)
	local sound = Instance.new("Sound")
	sound.SoundId = if typeof(assetId) == "number" then `rbxassetid://{assetId}` else assetId
	task.spawn(function()
		ContentProvider:PreloadAsync({ sound })
		sound:Destroy()
	end)
end

-- No instance pool in the classic implementation; kept for API compatibility.
function AudioUtil.warm(_count: number) end

-- Inserts a sidechained AudioCompressor on the target group. Returns a teardown
-- function; if `source` is an AudioHandle, teardown also fires automatically
-- when the handle finishes.
function AudioUtil.duck(targetGroup: MixGroup, source: any, opts: DuckOptions?): () -> ()
	local options: DuckOptions = opts or {}
	local group = getSoundGroup(targetGroup)

	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Threshold = options.threshold or -18
	compressor.Ratio = options.ratio or 6
	compressor.Attack = options.attack or 0.005
	compressor.Release = options.release or 0.2
	compressor.GainMakeup = options.makeupGain or 0
	compressor.SideChain = resolveSoundGroup(source)
	compressor.Parent = group

	local tornDown = false
	local function teardown()
		if tornDown then
			return
		end
		tornDown = true
		compressor:Destroy()
	end

	if type(source) == "table" and source.finished then
		(source.finished :: RBXScriptSignal):Once(teardown)
	end

	return teardown
end

return AudioUtil

--[=[
	@class AnimationUtils

	Helpers for fetching animation keyframe data and tweening track weights.
]=]

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local AssetUtil = require("./AssetUtil")
local Promise = require("../Promise")
local StringUtil = require("./StringUtil")

local keyFrameSequences: { [string]: KeyframeSequence } = {}
local markerTimesCache: { [string]: { number } } = {}
local lengthCache: { [string]: number } = {}

local function tweenAnimationWeight(track: AnimationTrack, info: TweenInfo, weight: number)
	local weightValue = Instance.new("NumberValue")
	weightValue.Value = track.WeightCurrent
	weightValue.Changed:Connect(function()
		track:AdjustWeight(weightValue.Value)
	end)

	local tween = game:GetService("TweenService"):Create(weightValue, info, { Value = weight })
	tween.Completed:Once(function()
		weightValue:Destroy()
	end)
	tween:Play()
	return tween
end

local function waitForAnimation(track: AnimationTrack)
	if not track.IsPlaying then
		return Promise.resolve()
	end

	if track.Length > 0 then
		return Promise.resolve()
	else
		return Promise.new(function(resolve, _, onCancel)
			local running = true
			onCancel(function()
				running = false
			end)

			repeat
				task.wait()
			until track.Length > 0 or not running

			resolve()
		end)
	end
end

--[=[
	@within AnimationUtils
	@param animationId (string | number) -- the animation's asset id or content string
	@return KeyframeSequence? -- Keyframe sequence from the animations asset id or content string

	Yields once to fetch the animation's keyframes (cached thereafter), then returns when the
	keyframe sequence
]=]
local function getKeyframeSequence(animationId: AssetUtil.AssetId): KeyframeSequence?
	local content = AssetUtil.toContent(animationId)
	if content == nil then
		return nil
	end

	local cached = keyFrameSequences[content]
	if cached then
		return cached
	end

	local ok, sequence = pcall(function()
		return KeyframeSequenceProvider:GetKeyframeSequenceAsync(content)
	end)

	if not ok then
		return nil
	end

	keyFrameSequences[content] = sequence
	return sequence
end

local function findAnimation(model: Model, trackName: string): Animation?
	local animationsFolder = model:FindFirstChild("Animations")
	if not animationsFolder then
		return nil
	end

	local formattedTrackName = StringUtil.formatName(trackName)
	for _, animation in animationsFolder:GetDescendants() do
		if not animation:IsA("Animation") then
			continue
		end

		local rawName = animation.Parent == animationsFolder and animation.Name or animation.Parent.Name
		if StringUtil.formatName(rawName) == formattedTrackName then
			return animation
		end
	end

	return nil
end

--[=[
	@within AnimationUtils
	@param animationId (string | number) -- the animation's asset id or content string
	@param markerName string -- the animation event (keyframe marker) name to find
	@return { number } -- sorted seconds from the animation's start for every matching marker

	Yields once to fetch the animation's keyframes (cached thereafter), then returns all
	times where the named marker appears.
]=]
local function getMarkerTimes(animationId: AssetUtil.AssetId, markerName: string): { number }
	local content = AssetUtil.toContent(animationId)
	if content == nil then
		return {}
	end

	local cacheKey = `{content}_{markerName}`
	local cached = markerTimesCache[cacheKey]
	if cached then
		return table.clone(cached)
	end

	local sequence = getKeyframeSequence(content)
	if not sequence then
		return {}
	end

	local markerTimes = {}
	for _, keyframe in sequence:GetKeyframes() do
		if #keyframe:GetMarkers(markerName) > 0 then
			table.insert(markerTimes, keyframe.Time)
		end
	end

	table.sort(markerTimes)
	markerTimesCache[cacheKey] = markerTimes

	return table.clone(markerTimes)
end

--[=[
	@within AnimationUtils
	@param animationId (string | number) -- the animation's asset id or content string
	@param markerName string -- the animation event (keyframe marker) name to find
	@return number? -- seconds from the animation's start to the first such marker, or nil if absent
]=]
local function getMarkerTime(animationId: AssetUtil.AssetId, markerName: string): number?
	return getMarkerTimes(animationId, markerName)[1]
end

--[=[
	@within AnimationUtils
	@param animationId (string | number) -- the animation's asset id or content string
	@return number? -- seconds from animation start to the final keyframe, or nil if unavailable
]=]
local function getAnimationLength(animationId: AssetUtil.AssetId): number?
	local content = AssetUtil.toContent(animationId)
	if content == nil then
		return nil
	end

	if lengthCache[content] ~= nil then
		return lengthCache[content]
	end

	local sequence = getKeyframeSequence(content)
	if not sequence then
		return nil
	end

	local length = 0
	for _, keyframe in sequence:GetKeyframes() do
		length = math.max(length, keyframe.Time)
	end

	lengthCache[content] = length
	return length
end

--[=[
	@within AnimationUtils
	@param model Model -- rig model containing an `Animations` folder
	@param trackName string -- animation track name, normalized to a canonical form
	@param markerName string -- animation event (keyframe marker) name to find
	@return { number } -- sorted marker times for the named track
]=]
local function getTrackMarkerTimes(model: Model, trackName: string, markerName: string): { number }
	local animation = findAnimation(model, trackName)
	if not animation then
		return {}
	end

	return getMarkerTimes(animation.AnimationId, markerName)
end

--[=[
	@within AnimationUtils
	@param model Model -- rig model containing an `Animations` folder
	@param trackName string -- animation track name, normalized to a canonical form
	@return number? -- seconds from animation start to the final keyframe, or nil if unavailable
]=]
local function getTrackLength(model: Model, trackName: string): number?
	local animation = findAnimation(model, trackName)
	if not animation then
		return nil
	end

	return getAnimationLength(animation.AnimationId)
end

--[=[
	@within AnimationUtils
	@param tracks { [string]: AnimationTrack }? -- loaded track map keyed by normalized name
	@param name string? -- track name; normalized with `StringUtil.formatName` before lookup
	@return AnimationTrack? -- the loaded track, or nil when the map (or name) doesn't have it
]=]
local function getTrack(tracks: { [string]: AnimationTrack }?, name: string?): AnimationTrack?
	if not tracks or not name then
		return nil
	end

	return tracks[StringUtil.formatName(name)]
end

--[=[
	@within AnimationUtils
	@param tracks { [string]: AnimationTrack }? -- loaded track map keyed by normalized name
	@param name string? -- track name; normalized before lookup
	@param fadeTime number? -- fade-in seconds forwarded to `Play`
	@return AnimationTrack? -- the played track, or nil when the map doesn't have it
]=]
local function playTrack(tracks: { [string]: AnimationTrack }?, name: string?, fadeTime: number?): AnimationTrack?
	local track = getTrack(tracks, name)
	if track then
		track:Play(fadeTime)
	end

	return track
end

--[=[
	@within AnimationUtils
	@param tracks { [string]: AnimationTrack }? -- loaded track map keyed by normalized name
	@param name string? -- track name; normalized before lookup
	@param fadeTime number? -- fade-out seconds forwarded to `Stop`
]=]
local function stopTrack(tracks: { [string]: AnimationTrack }?, name: string?, fadeTime: number?)
	local track = getTrack(tracks, name)
	if track and track.IsPlaying then
		track:Stop(fadeTime)
	end
end

return {
	tweenAnimationWeight = tweenAnimationWeight,
	waitForAnimation = waitForAnimation,
	getKeyframeSequence = getKeyframeSequence,
	getMarkerTime = getMarkerTime,
	getMarkerTimes = getMarkerTimes,
	getAnimationLength = getAnimationLength,
	getTrackMarkerTimes = getTrackMarkerTimes,
	getTrackLength = getTrackLength,
	getTrack = getTrack,
	playTrack = playTrack,
	stopTrack = stopTrack,
}

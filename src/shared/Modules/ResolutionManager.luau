local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)

--[=[
	@class ResolutionManager

	The texture resolution ladder creations step down when an EditableImage cannot be allocated.

	Stateless by design: the active rung belongs to a creation, not to the module, so one player
	stepping down on the server cannot drop everybody else's resolution. Callers hold the index —
	[ModelInfo] carries it — and pass it back in.
]=]

--[=[
	@within ResolutionManager
	@return number -- how many rungs the ladder has
]=]
local function stepCount(): number
	return #CreationConfig.textureResolutionSteps
end

--[=[
	@within ResolutionManager
	@param index number -- a possibly out-of-range rung
	@return number -- the same index held inside the ladder
]=]
local function clampIndex(index: number): number
	return math.clamp(index, 1, #CreationConfig.textureResolutionSteps)
end

--[=[
	@within ResolutionManager
	@param index number -- the rung to read, clamped into range
	@return Vector2 -- the texture size for that rung
]=]
local function resolutionFor(index: number): Vector2
	return CreationConfig.textureResolutionSteps[clampIndex(index)]
end

return {
	stepCount = stepCount,
	clampIndex = clampIndex,
	resolutionFor = resolutionFor,
}

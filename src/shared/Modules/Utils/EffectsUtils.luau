--[=[
	@class EffectsUtils

	Thin re-export of the ForgeVFX runtime API for playing and tuning VFX
	prefabs. `emit`/`emitWithDepth` play a prefab; `recolor`/`resize`/`retime`
	mutate a prefab's tuning in place before it plays; `enable`/`disable`
	toggle a prefab's emitters. See the ForgeVFX package for the underlying
	implementation.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ForgeVFX = require(ReplicatedStorage.Packages.ForgeVFX)

--[=[
	@within EffectsUtils
	@function emit
	@param vfxOrScale number | Instance -- a scale factor, or the first VFX prefab to emit at scale 1
	@param ... Instance -- VFX prefabs to emit
	@return EmitEnv -- `{ Finished: Promise, Clear: () -> () }` for awaiting or clearing the effect

	Plays one or more VFX prefabs. Pass a leading number to scale every prefab,
	or pass prefabs directly to emit at their authored scale.
]=]
local emit = ForgeVFX.emit

--[=[
	@within EffectsUtils
	@function emitWithDepth
	@param depth number -- render depth applied to the emitted effect
	@param ... Instance -- VFX prefabs to emit
	@return EmitEnv -- `{ Finished: Promise, Clear: () -> () }` for awaiting or clearing the effect

	Like [EffectsUtil.emit] but emits at an explicit render depth.
]=]
local emitWithDepth = ForgeVFX.emitWithDepth

--[=[
	@within EffectsUtils
	@function recolor
	@param color Color3 -- the colour to apply
	@param mode "replace" | "multiply" -- overwrite the prefab's colours, or tint them
	@param ... Instance -- VFX prefabs to recolour, along with their descendants

	Recolours the colour-bearing parts of each prefab (particles, beams, trails,
	lights, decals) in place.
]=]
local recolor = ForgeVFX.recolor

--[=[
	@within EffectsUtils
	@function resize
	@param factor number -- scale multiplier
	@param ... Instance -- VFX prefabs to resize, along with their descendants

	Scales the spatial properties (sizes, widths, distances) of each prefab in place.
]=]
local resize = ForgeVFX.resize

--[=[
	@within EffectsUtils
	@function retime
	@param factor number -- speed multiplier; values above 1 play faster, below 1 slower
	@param ... Instance -- VFX prefabs to retime, along with their descendants

	Scales the temporal properties (durations, lifetimes, rates, speeds) of each
	prefab in place so it plays faster or slower.
]=]
local retime = ForgeVFX.retime

--[=[
	@within EffectsUtils
	@function enable
	@param obj Instance -- a VFX prefab or emitter; descendants are toggled too

	Enables the emitters (`ParticleEmitter`, `Beam`, …) under a prefab.
]=]
local enable = ForgeVFX.enable

--[=[
	@within EffectsUtils
	@function disable
	@param obj Instance -- a VFX prefab or emitter; descendants are toggled too

	Disables the emitters (`ParticleEmitter`, `Beam`, …) under a prefab.
]=]
local disable = ForgeVFX.disable

return {
	emit = emit,
	emitWithDepth = emitWithDepth,

	recolor = recolor,
	resize = resize,
	retime = retime,

	enable = enable,
	disable = disable,
}

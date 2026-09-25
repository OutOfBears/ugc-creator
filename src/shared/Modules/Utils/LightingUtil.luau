local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)

export type LightingServiceProps = {
	ClockTime: number?,
	ColorShift_Bottom: Color3?,
	ColorShift_Top: Color3?,
	FogColor: Color3?,
	FogStart: number?,
	FogEnd: number?,
	EnvironmentDiffuseScale: number?,
	EnvironmentSpecularScale: number?,
	ExposureCompensation: number?,
	GeographicLatitude: number?,
	Ambient: Color3?,
	OutdoorAmbient: Color3?,
	ShadowSoftness: number?,
	Brightness: number?,
	GlobalShadows: boolean?,
}

export type EffectProps = { [string]: any }
type CleanupCallback = () -> ()

export type LightingPreset = {
	Lighting: LightingServiceProps,
	Sky: EffectProps?,
	PostEffects: {
		Lighting: { [string]: EffectProps }?,
		Camera: { [string]: EffectProps }?,
	}?,
}

--[=[
	@class LightingUtil

	Applies a Lighting Manager preset — `Lighting` service properties, a `Sky`, and post-processing
	effects — to the live `Lighting` service and `Camera`. Presets are complete snapshots, so
	applying one overwrites the service properties and replaces the managed effect instances.
]=]
local LightingUtil = {}

local function spawnEffect(className: string, props: EffectProps, parent: Instance): Instance
	local maid = Maid.new()

	for _, child in parent:GetChildren() do
		if child.ClassName == className then
			local oldParent = child.Parent
			child.Parent = nil
			maid:add(function()
				child.Parent = oldParent
			end)
		end
	end

	local build = table.clone(props)
	build.Parent = parent

	local inst = Create(className, build)

	maid:add(function()
		inst:Destroy()
	end)

	return function()
		maid:doCleaning()
	end
end

--[=[
	@within LightingUtil
	@param preset LightingPreset -- the Lighting Manager export to apply
	@return { Instance } -- the Sky/effect instances created, for the caller to own and clean up

	Sets the service properties, then replaces the `Sky` and post-processing effects. Any existing
	child of the same class under each parent is removed first, so the preset is authoritative
	regardless of what was authored in Studio.
]=]
function LightingUtil.apply(preset: LightingPreset): { Instance }
	local maid = Maid.new()

	for key, value in preset.Lighting :: any do
		local oldValue = Lighting[key]
		Lighting[key] = value

		maid:add(function()
			(Lighting :: any)[key] = oldValue
		end)
	end

	if preset.Sky then
		maid:add(spawnEffect("Sky", preset.Sky, Lighting))
	end

	local postEffects = preset.PostEffects
	if postEffects then
		if postEffects.Lighting then
			for className, props in postEffects.Lighting do
				maid:add(spawnEffect(className, props, Lighting))
			end
		end

		local camera = workspace.CurrentCamera
		if postEffects.Camera and camera then
			for className, props in postEffects.Camera do
				maid:add(spawnEffect(className, props, camera))
			end
		end
	end

	return function()
		maid:doCleaning()
	end
end

return LightingUtil

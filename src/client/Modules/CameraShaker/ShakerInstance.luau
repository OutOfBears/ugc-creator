-- Camera Shake Instance
-- Stephen Leitnick
-- February 26, 2018

--[=[
	@class ShakerInstance
	@client

	A single Perlin-noise shake with fade-in/out and sustain. Optionally anchored to a
	world position via [ShakerInstance:SetPosition], in which case [CameraShaker] attenuates
	it by the camera's distance from that source. Construct with `CameraShakeInstance.new`
	or a [CameraShaker] preset, then feed it to a [CameraShaker].
]=]

local Config = require("./Config")

type FalloffId = Config.FalloffId

type CameraShakeInstanceImpl = {
	__index: CameraShakeInstanceImpl,
	UpdateShake: (self: CameraShakeInstance, dt: number) -> Vector3,
	SetPosition: (
		self: CameraShakeInstance,
		position: Vector3,
		radius: number?,
		falloff: FalloffId?
	) -> CameraShakeInstance,
	StartFadeOut: (self: CameraShakeInstance, fadeOutTime: number) -> (),
	StartFadeIn: (self: CameraShakeInstance, fadeInTime: number?) -> (),
	GetScaleRoughness: (self: CameraShakeInstance) -> number,
	SetScaleRoughness: (self: CameraShakeInstance, v: number) -> (),
	GetScaleMagnitude: (self: CameraShakeInstance) -> number,
	SetScaleMagnitude: (self: CameraShakeInstance, v: number) -> (),
	GetNormalizedFadeTime: (self: CameraShakeInstance) -> number,
	IsShaking: (self: CameraShakeInstance) -> boolean,
	IsFadingOut: (self: CameraShakeInstance) -> boolean,
	IsFadingIn: (self: CameraShakeInstance) -> boolean,
	GetState: (self: CameraShakeInstance) -> number,
}

export type CameraShakeInstance = typeof(setmetatable(
	{} :: {
		Magnitude: number,
		Roughness: number,
		PositionInfluence: Vector3,
		RotationInfluence: Vector3,
		DeleteOnInactive: boolean,
		position: Vector3?,
		radius: number,
		falloff: FalloffId,
		roughMod: number,
		magnMod: number,
		fadeOutDuration: number,
		fadeInDuration: number,
		sustain: boolean,
		currentFadeTime: number,
		tick: number,
		_camShakeInstance: boolean,
	},
	{} :: CameraShakeInstanceImpl
))

local CameraShakeInstance = {}

CameraShakeInstance.__index = CameraShakeInstance

local V3 = Vector3.new
local NOISE = math.noise

CameraShakeInstance.CameraShakeState = {
	FadingIn = 0,
	FadingOut = 1,
	Sustained = 2,
	Inactive = 3,
}

function CameraShakeInstance.new(magnitude, roughness, fadeInTime, fadeOutTime): CameraShakeInstance
	if fadeInTime == nil then
		fadeInTime = 0
	end
	if fadeOutTime == nil then
		fadeOutTime = 0
	end

	assert(type(magnitude) == "number", "Magnitude must be a number")
	assert(type(roughness) == "number", "Roughness must be a number")
	assert(type(fadeInTime) == "number", "FadeInTime must be a number")
	assert(type(fadeOutTime) == "number", "FadeOutTime must be a number")

	local self = setmetatable({
		Magnitude = magnitude,
		Roughness = roughness,
		PositionInfluence = V3(),
		RotationInfluence = V3(),
		DeleteOnInactive = true,
		position = nil,
		radius = Config.DEFAULT_RADIUS,
		falloff = Config.DEFAULT_FALLOFF,
		roughMod = 1,
		magnMod = 1,
		fadeOutDuration = fadeOutTime,
		fadeInDuration = fadeInTime,
		sustain = (fadeInTime > 0),
		currentFadeTime = (fadeInTime > 0 and 0 or 1),
		tick = Random.new():NextNumber(-100, 100),
		_camShakeInstance = true,
	}, CameraShakeInstance)

	return self
end

--[=[
	@within ShakerInstance
	@private
	@param dt number -- delta time since the last frame
]=]
function CameraShakeInstance:UpdateShake(dt)
	local _tick = self.tick
	local currentFadeTime = self.currentFadeTime

	local offset = V3(NOISE(_tick, 0) * 0.5, NOISE(0, _tick) * 0.5, NOISE(_tick, _tick) * 0.5)

	if self.fadeInDuration > 0 and self.sustain then
		if currentFadeTime < 1 then
			currentFadeTime = currentFadeTime + (dt / self.fadeInDuration)
		elseif self.fadeOutDuration > 0 then
			self.sustain = false
		end
	end

	if not self.sustain then
		currentFadeTime = currentFadeTime - (dt / self.fadeOutDuration)
	end

	if self.sustain then
		self.tick = _tick + (dt * self.Roughness * self.roughMod)
	else
		self.tick = _tick + (dt * self.Roughness * self.roughMod * currentFadeTime)
	end

	self.currentFadeTime = currentFadeTime

	return offset * self.Magnitude * self.magnMod * currentFadeTime
end

--[=[
	@within ShakerInstance
	@param position Vector3 -- world-space source the shake radiates from
	@param radius number? -- studs at which the shake fades to nothing (defaults to Config.DEFAULT_RADIUS)
	@param falloff FalloffId? -- attenuation curve to use (defaults to Config.DEFAULT_FALLOFF)
	@return CameraShakeInstance -- self, for chaining

	Anchors the shake to a world position so [CameraShaker] attenuates it by the camera's
	distance from `position`. Beyond `radius` the shake contributes nothing.
]=]
function CameraShakeInstance:SetPosition(position, radius, falloff)
	self.position = position
	self.radius = radius or self.radius
	self.falloff = falloff or self.falloff
	return self
end

--[=[
	@within ShakerInstance
	@param fadeOutTime number -- seconds to fade to zero
]=]
function CameraShakeInstance:StartFadeOut(fadeOutTime)
	if fadeOutTime == 0 then
		self.currentFadeTime = 0
	end
	self.fadeOutDuration = fadeOutTime
	self.fadeInDuration = 0
	self.sustain = false
end

--[=[
	@within ShakerInstance
	@param fadeInTime number? -- seconds to ramp up to full magnitude
]=]
function CameraShakeInstance:StartFadeIn(fadeInTime)
	if fadeInTime == 0 then
		self.currentFadeTime = 1
	end
	self.fadeInDuration = fadeInTime or self.fadeInDuration
	self.fadeOutDuration = 0
	self.sustain = true
end

--[=[
	@within ShakerInstance
	@return number
]=]
function CameraShakeInstance:GetScaleRoughness()
	return self.roughMod
end

--[=[
	@within ShakerInstance
	@param v number
]=]
function CameraShakeInstance:SetScaleRoughness(v)
	self.roughMod = v
end

--[=[
	@within ShakerInstance
	@return number
]=]
function CameraShakeInstance:GetScaleMagnitude()
	return self.magnMod
end

--[=[
	@within ShakerInstance
	@param v number
]=]
function CameraShakeInstance:SetScaleMagnitude(v)
	self.magnMod = v
end

--[=[
	@within ShakerInstance
	@return number -- fade progress in the range 0..1
]=]
function CameraShakeInstance:GetNormalizedFadeTime()
	return self.currentFadeTime
end

--[=[
	@within ShakerInstance
	@return boolean -- true while the shake still contributes any motion
]=]
function CameraShakeInstance:IsShaking()
	return (self.currentFadeTime > 0 or self.sustain)
end

--[=[
	@within ShakerInstance
	@return boolean
]=]
function CameraShakeInstance:IsFadingOut()
	return ((not self.sustain) and self.currentFadeTime > 0)
end

--[=[
	@within ShakerInstance
	@return boolean
]=]
function CameraShakeInstance:IsFadingIn()
	return (self.currentFadeTime < 1 and self.sustain and self.fadeInDuration > 0)
end

--[=[
	@within ShakerInstance
	@return number -- one of CameraShakeInstance.CameraShakeState
]=]
function CameraShakeInstance:GetState()
	if self:IsFadingIn() then
		return CameraShakeInstance.CameraShakeState.FadingIn
	elseif self:IsFadingOut() then
		return CameraShakeInstance.CameraShakeState.FadingOut
	elseif self:IsShaking() then
		return CameraShakeInstance.CameraShakeState.Sustained
	else
		return CameraShakeInstance.CameraShakeState.Inactive
	end
end

return CameraShakeInstance

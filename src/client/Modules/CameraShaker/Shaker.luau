-- Camera Shaker
-- Stephen Leitnick
-- February 26, 2018

--[[

	CameraShaker.CameraShakeInstance

	cameraShaker = CameraShaker.new(renderPriority, callbackFunction)

	CameraShaker:Start()
	CameraShaker:Stop()
	CameraShaker:StopSustained([fadeOutTime])
	CameraShaker:Shake(shakeInstance)
	CameraShaker:ShakeSustain(shakeInstance)
	CameraShaker:ShakeOnce(magnitude, roughness [, fadeInTime, fadeOutTime, posInfluence, rotInfluence])
	CameraShaker:StartShake(magnitude, roughness [, fadeInTime, posInfluence, rotInfluence])
	CameraShaker:ShakeAtPosition(shakeInstance, position [, radius, falloff])



	EXAMPLE:

		local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
			camera.CFrame = playerCFrame * shakeCFrame
		end)

		camShake:Start()

		-- Explosion shake:
		camShake:Shake(CameraShaker.Presets.Explosion)

		wait(1)

		-- Custom shake:
		camShake:ShakeOnce(3, 1, 0.2, 1.5)

		-- Sustained shake:
		camShake:ShakeSustain(CameraShaker.Presets.Earthquake)

		-- Stop all sustained shakes:
		camShake:StopSustained(1) -- Argument is the fadeout time (defaults to the same as fadein time if not supplied)

		-- Stop only one sustained shake:
		shakeInstance = camShake:ShakeSustain(CameraShaker.Presets.Earthquake)
		wait(2)
		shakeInstance:StartFadeOut(1) -- Argument is the fadeout time

		-- Localized explosion shake that falls off with distance:
		camShake:ShakeAtPosition(CameraShaker.Presets.Explosion(), hitPosition, 80, "Exponential")


	NOTE:

		This was based entirely on the EZ Camera Shake asset for Unity3D. I was given written
		permission by the developer, Road Turtle Games, to port this to Roblox.

		Original asset link: https://assetstore.unity.com/packages/tools/camera/ez-camera-shake-33148

		GitHub repository: https://github.com/Sleitnick/RbxCameraShaker


--]]

local profileBegin = debug.profilebegin
local profileEnd = debug.profileend
local profileTag = "CameraShakerUpdate"

local CF = CFrame.new
local ANG = CFrame.Angles
local RAD = math.rad
local v3Zero = Vector3.zero

local CameraShakeInstance = require("./ShakerInstance")
local Config = require("./Config")
local CameraShakeState = CameraShakeInstance.CameraShakeState

type ShakeInstance = CameraShakeInstance.CameraShakeInstance
type FalloffId = Config.FalloffId

type CameraShakerImpl = {
	__index: CameraShakerImpl,
	Start: (self: CameraShaker) -> (),
	Stop: (self: CameraShaker) -> (),
	StopSustained: (self: CameraShaker, duration: number?) -> (),
	Update: (self: CameraShaker, dt: number) -> CFrame,
	Shake: (self: CameraShaker, shakeInstance: ShakeInstance) -> ShakeInstance,
	ShakeSustain: (self: CameraShaker, shakeInstance: ShakeInstance) -> ShakeInstance,
	ShakeOnce: (
		self: CameraShaker,
		magnitude: number,
		roughness: number,
		fadeInTime: number?,
		fadeOutTime: number?,
		posInfluence: Vector3?,
		rotInfluence: Vector3?
	) -> ShakeInstance,
	StartShake: (
		self: CameraShaker,
		magnitude: number,
		roughness: number,
		fadeInTime: number?,
		posInfluence: Vector3?,
		rotInfluence: Vector3?
	) -> ShakeInstance,
	ShakeAtPosition: (
		self: CameraShaker,
		shakeInstance: ShakeInstance,
		position: Vector3,
		radius: number?,
		falloff: FalloffId?
	) -> ShakeInstance,
}

export type CameraShaker = typeof(setmetatable(
	{} :: {
		_running: boolean,
		_renderName: string,
		_renderPriority: number,
		_posAddShake: Vector3,
		_rotAddShake: Vector3,
		_camShakeInstances: { ShakeInstance },
		_removeInstances: { number },
		_callback: (cf: CFrame) -> (),
	},
	{} :: CameraShakerImpl
))

--[=[
	@class CameraShaker
	@client

	Perlin-noise camera shaker. Accumulates any number of concurrent [ShakerInstance] shakes
	each frame and hands the combined CFrame offset to a callback. Shakes may be global or,
	via [CameraShaker:ShakeAtPosition], anchored to a world position and attenuated by the
	camera's distance from that source through a [Config.FalloffId] curve.
]=]
local CameraShaker = {}
CameraShaker.__index = CameraShaker

CameraShaker.CameraShakeInstance = CameraShakeInstance
CameraShaker.Presets = require("./ShakerPresets")

--[=[
	@within CameraShaker
	@param renderPriority number -- BindToRenderStep priority (e.g. Enum.RenderPriority.Camera.Value)
	@param callback (cf: CFrame) -> () -- receives the combined shake offset each frame
	@return CameraShaker
]=]
function CameraShaker.new(renderPriority, callback): CameraShaker
	assert(type(renderPriority) == "number", "RenderPriority must be a number (e.g.: Enum.RenderPriority.Camera.Value)")
	assert(type(callback) == "function", "Callback must be a function")

	local self = setmetatable({
		_running = false,
		_renderName = "CameraShaker",
		_renderPriority = renderPriority,
		_posAddShake = v3Zero,
		_rotAddShake = v3Zero,
		_camShakeInstances = {},
		_removeInstances = {},
		_callback = callback,
	}, CameraShaker)

	return self
end

--[=[
	@within CameraShaker

	Binds to render step and begins driving the callback each frame.
]=]
function CameraShaker:Start()
	if self._running then
		return
	end
	self._running = true
	local callback = self._callback
	game:GetService("RunService"):BindToRenderStep(self._renderName, self._renderPriority, function(dt)
		profileBegin(profileTag)
		local cf = self:Update(dt)
		profileEnd()
		callback(cf)
	end)
end

--[=[
	@within CameraShaker

	Unbinds from render step and stops driving the callback.
]=]
function CameraShaker:Stop()
	if not self._running then
		return
	end
	game:GetService("RunService"):UnbindFromRenderStep(self._renderName)
	self._running = false
end

--[=[
	@within CameraShaker
	@param duration number? -- fade-out time (defaults to each shake's fade-in duration)

	Fades out every currently sustained shake.
]=]
function CameraShaker:StopSustained(duration)
	for _, c in pairs(self._camShakeInstances) do
		if c.fadeOutDuration == 0 then
			c:StartFadeOut(duration or c.fadeInDuration)
		end
	end
end

--[=[
	@within CameraShaker
	@private
	@param dt number -- delta time since the last frame
]=]
function CameraShaker:Update(dt)
	local posAddShake = v3Zero
	local rotAddShake = v3Zero

	local camera = workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else nil

	local instances = self._camShakeInstances

	-- Update all instances:
	for i = 1, #instances do
		local c = instances[i]
		local state = c:GetState()

		if state == CameraShakeState.Inactive and c.DeleteOnInactive then
			self._removeInstances[#self._removeInstances + 1] = i
		elseif state ~= CameraShakeState.Inactive then
			local shake = c:UpdateShake(dt)

			if c.position and camPos then
				local dist = (camPos - c.position).Magnitude
				if dist >= c.radius then
					shake = v3Zero
				else
					shake = shake * Config.falloffs[c.falloff](dist / c.radius)
				end
			end

			posAddShake = posAddShake + (shake * c.PositionInfluence)
			rotAddShake = rotAddShake + (shake * c.RotationInfluence)
		end
	end

	-- Remove dead instances:
	for i = #self._removeInstances, 1, -1 do
		local instIndex = self._removeInstances[i]
		table.remove(instances, instIndex)
		self._removeInstances[i] = nil
	end

	return CF(posAddShake) * ANG(0, RAD(rotAddShake.Y), 0) * ANG(RAD(rotAddShake.X), 0, RAD(rotAddShake.Z))
end

--[=[
	@within CameraShaker
	@param shakeInstance ShakerInstance -- the shake to add
	@return ShakerInstance -- the same instance, for later control

	Queues a one-shot shake.
]=]
function CameraShaker:Shake(shakeInstance)
	assert(
		type(shakeInstance) == "table" and shakeInstance._camShakeInstance,
		"ShakeInstance must be of type CameraShakeInstance"
	)
	self._camShakeInstances[#self._camShakeInstances + 1] = shakeInstance
	return shakeInstance
end

--[=[
	@within CameraShaker
	@param shakeInstance ShakerInstance -- the shake to add
	@return ShakerInstance -- the same instance, for later control

	Queues a sustained shake and starts its fade-in.
]=]
function CameraShaker:ShakeSustain(shakeInstance)
	assert(
		type(shakeInstance) == "table" and shakeInstance._camShakeInstance,
		"ShakeInstance must be of type CameraShakeInstance"
	)
	self._camShakeInstances[#self._camShakeInstances + 1] = shakeInstance
	shakeInstance:StartFadeIn(shakeInstance.fadeInDuration)
	return shakeInstance
end

--[=[
	@within CameraShaker
	@param magnitude number
	@param roughness number
	@param fadeInTime number?
	@param fadeOutTime number?
	@param posInfluence Vector3?
	@param rotInfluence Vector3?
	@return ShakerInstance

	Builds and queues a one-shot shake in a single call.
]=]
function CameraShaker:ShakeOnce(magnitude, roughness, fadeInTime, fadeOutTime, posInfluence, rotInfluence)
	local shakeInstance = CameraShakeInstance.new(magnitude, roughness, fadeInTime, fadeOutTime)
	shakeInstance.PositionInfluence = (typeof(posInfluence) == "Vector3" and posInfluence or Config.defaultPosInfluence)
	shakeInstance.RotationInfluence = (typeof(rotInfluence) == "Vector3" and rotInfluence or Config.defaultRotInfluence)
	self._camShakeInstances[#self._camShakeInstances + 1] = shakeInstance
	return shakeInstance
end

--[=[
	@within CameraShaker
	@param magnitude number
	@param roughness number
	@param fadeInTime number?
	@param posInfluence Vector3?
	@param rotInfluence Vector3?
	@return ShakerInstance

	Builds and queues a sustained shake (with fade-in) in a single call.
]=]
function CameraShaker:StartShake(magnitude, roughness, fadeInTime, posInfluence, rotInfluence)
	local shakeInstance = CameraShakeInstance.new(magnitude, roughness, fadeInTime)
	shakeInstance.PositionInfluence = (typeof(posInfluence) == "Vector3" and posInfluence or Config.defaultPosInfluence)
	shakeInstance.RotationInfluence = (typeof(rotInfluence) == "Vector3" and rotInfluence or Config.defaultRotInfluence)
	shakeInstance:StartFadeIn(fadeInTime)
	self._camShakeInstances[#self._camShakeInstances + 1] = shakeInstance
	return shakeInstance
end

--[=[
	@within CameraShaker
	@param shakeInstance ShakerInstance -- the shake to localize and add (e.g. a preset)
	@param position Vector3 -- world-space source the shake radiates from
	@param radius number? -- studs at which the shake fades to nothing
	@param falloff FalloffId? -- attenuation curve to use
	@return ShakerInstance -- the same instance, for later control

	Anchors `shakeInstance` to `position` and queues it, so its magnitude is attenuated by
	the camera's distance from that source. Composes with presets:
	`shaker:ShakeAtPosition(CameraShaker.Presets.Explosion(), hitPos, 80, "Exponential")`.
]=]
function CameraShaker:ShakeAtPosition(shakeInstance, position, radius, falloff)
	assert(
		type(shakeInstance) == "table" and shakeInstance._camShakeInstance,
		"ShakeInstance must be of type CameraShakeInstance"
	)
	shakeInstance:SetPosition(position, radius, falloff)
	self._camShakeInstances[#self._camShakeInstances + 1] = shakeInstance
	return shakeInstance
end

return CameraShaker

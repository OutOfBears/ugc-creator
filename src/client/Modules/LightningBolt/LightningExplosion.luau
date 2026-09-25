local RunService = game:GetService("RunService")

local LightningBolt = require("../LightningBolt")
local LightningSparks = require("./LightningSparks")

local EXPLOSION_DURATION = 0.7
local EMITTER_CUTOFF_TIME = 0.2

export type LightningExplosion = {
	-- vars
	size: number,
	numBolts: number,
	color: Color3 | ColorSequence,
	boltColor: Color3 | ColorSequence,
	upVector: Vector3,
	bolts: { { bolt: LightningBolt.LightningBolt, velocity: Vector3 } },
	attachment: Attachment,
	part: BasePart,
	startT: number,
	refIndex: number,

	-- methods
	destroy: (self: LightningExplosion) -> (),
}

local activeExplosions: { [number]: LightningExplosion } = {}
local rng = Random.new()
local assets = script.Parent.LightningAssets

local function randomVectorOffsetBetween(v: Vector3, minAngle: number, maxAngle: number): Vector3
	return (CFrame.lookAt(Vector3.zero, v) * CFrame.Angles(0, 0, rng:NextNumber(0, 2 * math.pi)) * CFrame.Angles(
		math.acos(rng:NextNumber(math.cos(maxAngle), math.cos(minAngle))),
		0,
		0
	)).LookVector
end

--[=[
	@class LightningExplosion

	A burst of [LightningBolt]s radiating from a point, with particle emitters
	for the flash. Properties are read once at construction — changing them on
	the returned object afterwards has no effect.
]=]
local LightningExplosion = {}

--[=[
	@within LightningExplosion
	@param position Vector3 -- world position of the burst
	@param size number? -- relative scale between 0 and 1 (defaults to 1)
	@param numBolts number? -- number of bolts shot out (defaults to 14)
	@param color (Color3 | ColorSequence)? -- emitter color (defaults to red→blue)
	@param boltColor (Color3 | ColorSequence)? -- bolt color (defaults to light blue)
	@param upVector Vector3? -- direction the burst points (defaults to up)
	@return LightningExplosion
]=]
function LightningExplosion.new(
	position: Vector3,
	size: number?,
	numBolts: number?,
	color: (Color3 | ColorSequence)?,
	boltColor: (Color3 | ColorSequence)?,
	upVector: Vector3?
): LightningExplosion
	local object = {} :: LightningExplosion

	object.size = size or 1
	object.numBolts = numBolts or 14
	object.color = color or ColorSequence.new(Color3.new(1, 0, 0), Color3.new(0, 0, 1))
	object.boltColor = boltColor or Color3.new(0.3, 0.3, 1)
	object.upVector = upVector or Vector3.new(0, 1, 0)

	local parent = workspace.CurrentCamera

	local part = Instance.new("Part")
	part.Name = "LightningExplosion"
	part.Anchored = true
	part.CanCollide = false
	part.Locked = true
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.05, 0.05, 0.05)
	part.CFrame = CFrame.lookAt(position + Vector3.new(0, 0.5, 0), position + Vector3.new(0, 0.5, 0) + object.upVector)
		* CFrame.lookAt(Vector3.zero, Vector3.new(0, 1, 0)):Inverse()
	part.Parent = parent

	local attach = Instance.new("Attachment")
	attach.Parent = part
	attach.CFrame = CFrame.new()

	local partEmit1 = assets.ExplosionBrightspot:Clone()
	local partEmit2 = assets.GlareEmitter:Clone()
	local partEmit3 = assets.PlasmaEmitter:Clone()

	local partSize = math.clamp(object.size, 0, 1)

	partEmit2.Size = NumberSequence.new(30 * partSize)
	partEmit3.Size = NumberSequence.new(18 * partSize)
	partEmit3.Speed = NumberRange.new(100 * partSize)

	partEmit1.Parent = attach
	partEmit2.Parent = attach
	partEmit3.Parent = attach

	local currentColor = object.color

	if typeof(currentColor) == "Color3" then
		partEmit2.Color, partEmit3.Color = ColorSequence.new(currentColor), ColorSequence.new(currentColor)

		local cH, _, cV = Color3.toHSV(currentColor)
		partEmit1.Color = ColorSequence.new(Color3.fromHSV(cH, 0.5, cV))
	else
		partEmit2.Color, partEmit3.Color = currentColor, currentColor

		local keypoints = currentColor.Keypoints
		for i = 1, #keypoints do
			local cH, _, cV = Color3.toHSV(keypoints[i].Value)
			keypoints[i] = ColorSequenceKeypoint.new(keypoints[i].Time, Color3.fromHSV(cH, 0.5, cV))
		end
		partEmit1.Color = ColorSequence.new(keypoints)
	end

	partEmit1.Enabled, partEmit2.Enabled, partEmit3.Enabled = true, true, true

	object.bolts = {}

	for _ = 1, object.numBolts do
		local a1, a2 = {}, {}

		a1.WorldPosition, a1.WorldAxis =
			attach.WorldPosition, randomVectorOffsetBetween(object.upVector, math.rad(65), math.rad(80))
		a2.WorldPosition, a2.WorldAxis =
			attach.WorldPosition + a1.WorldAxis * rng:NextNumber(20, 40) * 1.4 * partSize,
			randomVectorOffsetBetween(-object.upVector, math.rad(70), math.rad(110))

		local newBolt = LightningBolt.new(a1, a2, 10)
		newBolt.animationSpeed = 0
		newBolt.thickness = 1
		newBolt.color = object.boltColor
		newBolt.pulseLength = 0.8
		newBolt.colorOffsetSpeed = 20
		newBolt.frequency = 2
		newBolt.minRadius, newBolt.maxRadius = 0, 4 * partSize
		newBolt.fadeLength = 0.4
		newBolt.pulseSpeed = 5
		newBolt.minThicknessMultiplier, newBolt.maxThicknessMultiplier = 0.7, 1

		local newSparks = LightningSparks.new(newBolt, 5)
		newSparks.minDistance, newSparks.maxDistance = 7.5, 10

		local velocity = (a2.WorldPosition - a1.WorldPosition).Unit * 0.1 * partSize
		table.insert(object.bolts, { bolt = newBolt, velocity = velocity })
	end

	object.attachment = attach
	object.part = part
	object.startT = os.clock()
	object.refIndex = #activeExplosions + 1

	function object:destroy()
		activeExplosions[self.refIndex] = nil
		self.part:Destroy()
		table.clear(self.bolts)
	end

	activeExplosions[object.refIndex] = object

	return object
end

RunService.Heartbeat:Connect(function()
	for _, explosion in activeExplosions do
		local timePassed = os.clock() - explosion.startT

		if timePassed >= EXPLOSION_DURATION then
			explosion:destroy()
			continue
		end

		local attach = explosion.attachment

		if timePassed > EMITTER_CUTOFF_TIME then
			attach.ExplosionBrightspot.Enabled, attach.GlareEmitter.Enabled, attach.PlasmaEmitter.Enabled =
				false, false, false
		end

		for _, entry in explosion.bolts do
			local bolt = entry.bolt
			bolt.attachment1.WorldPosition = bolt.attachment1.WorldPosition + entry.velocity
		end
	end
end)

return LightningExplosion

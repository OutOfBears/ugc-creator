local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PartCache = require(ReplicatedStorage.Shared.Modules.PartCache)

local X_INVERSE = CFrame.lookAt(Vector3.zero, Vector3.new(1, 0, 0)):Inverse()
local OFFSET_ANGLE = math.cos(math.rad(90))
local DEFAULT_PART_COUNT = 30
local CACHE_SIZE = 150
local CACHE_EXPAND = 200

export type BoltAttachment = {
	WorldPosition: Vector3,
	WorldAxis: Vector3,
}

export type LightningBolt = {
	-- vars
	enabled: boolean,
	attachment0: BoltAttachment,
	attachment1: BoltAttachment,
	curveSize0: number,
	curveSize1: number,
	minRadius: number,
	maxRadius: number,
	frequency: number,
	animationSpeed: number,
	thickness: number,
	minThicknessMultiplier: number,
	maxThicknessMultiplier: number,
	minTransparency: number,
	maxTransparency: number,
	pulseSpeed: number,
	pulseLength: number,
	fadeLength: number,
	contractFrom: number,
	color: Color3 | ColorSequence,
	colorOffsetSpeed: number,
	parts: { BasePart },
	destroyed: boolean,
	partsHidden: boolean,
	disabledTransparency: number,
	startT: number,
	ranNum: number,
	refIndex: number,

	-- methods
	destroy: (self: LightningBolt) -> (),
}

local activeBolts: { [number]: LightningBolt } = {}
local nextBoltId = 0

local function discretePulse(
	input: number,
	s: number,
	k: number,
	f: number,
	t: number,
	min: number,
	max: number
): number
	return math.clamp(k / (2 * f) - math.abs((input - t * s + 0.5 * k) / f), min, max)
end

local function noiseBetween(x: number, y: number, z: number, min: number, max: number): number
	return min + (max - min) * (math.noise(x, y, z) + 0.5)
end

local function cubicBezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	return p0 * (1 - t) ^ 3 + p1 * 3 * t * (1 - t) ^ 2 + p2 * 3 * (1 - t) * t ^ 2 + p3 * t ^ 3
end

local boltTemplate = Instance.new("Part")
boltTemplate.TopSurface, boltTemplate.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
boltTemplate.Anchored, boltTemplate.CanCollide = true, false
boltTemplate.Shape = Enum.PartType.Cylinder
boltTemplate.Name = "BoltPart"
boltTemplate.CanTouch = false
boltTemplate.CastShadow = false
boltTemplate.CanQuery = false
boltTemplate.Material = Enum.Material.Neon
boltTemplate.Color = Color3.new(1, 1, 1)
boltTemplate.Transparency = 1
boltTemplate.Locked = true

local cache: any = nil

local function getCache()
	if not cache then
		cache = PartCache.new(boltTemplate, CACHE_SIZE, workspace.CurrentCamera)
		cache:setExpandAmount(CACHE_EXPAND)
	end

	return cache
end

local function stepBolt(branch: LightningBolt)
	if not branch.enabled then
		if not branch.partsHidden then
			branch.partsHidden = true

			local disabledTransparency = branch.disabledTransparency
			for i = 1, #branch.parts do
				branch.parts[i].Transparency = disabledTransparency
			end
		end

		return
	end

	branch.partsHidden = false

	local minOpa, maxOpa = 1 - branch.maxTransparency, 1 - branch.minTransparency
	local minRadius, maxRadius = branch.minRadius, branch.maxRadius
	local thickness = branch.thickness
	local parts = branch.parts
	local partsN = #parts
	local ranNum = branch.ranNum
	local startT = branch.startT
	local spd = branch.animationSpeed
	local freq = branch.frequency
	local minThick, maxThick = branch.minThicknessMultiplier, branch.maxThicknessMultiplier
	local a0, a1, curveSize0, curveSize1 = branch.attachment0, branch.attachment1, branch.curveSize0, branch.curveSize1
	local p0, p1, p2, p3 =
		a0.WorldPosition,
		a0.WorldPosition + a0.WorldAxis * curveSize0,
		a1.WorldPosition - a1.WorldAxis * curveSize1,
		a1.WorldPosition
	local timePassed = os.clock() - startT
	local pulseLength, pulseSpeed, fadeLength = branch.pulseLength, branch.pulseSpeed, branch.fadeLength
	local color = branch.color
	local colorOffsetSpeed = branch.colorOffsetSpeed
	local contractF = 1 - branch.contractFrom

	local prevPoint, bezier0 = p0, p0

	if timePassed >= (pulseLength + 1) / pulseSpeed then
		branch:destroy()
		return
	end

	for i = 1, partsN do
		local part = parts[i]
		local t1 = i / partsN
		local opacity = discretePulse(t1, pulseSpeed, pulseLength, fadeLength, timePassed, minOpa, maxOpa)
		local bezier1 = cubicBezier(p0, p1, p2, p3, t1)
		local time = -timePassed
		local input, input2 =
			(spd * time) + freq * 10 * t1 - 0.2 + ranNum * 4, 5 * ((spd * 0.01 * time) / 10 + freq * t1) + ranNum * 4
		local noise0 = noiseBetween(5 * input, 1.5, 5 * 0.2 * input2, 0, 0.1 * 2 * math.pi)
			+ noiseBetween(0.5 * input, 1.5, 0.5 * 0.2 * input2, 0, 0.9 * 2 * math.pi)
		local noise1 = noiseBetween(3.4, input2, input, minRadius, maxRadius) * math.exp(-5000 * (t1 - 0.5) ^ 10)
		local thicknessNoise = noiseBetween(2.3, input2, input, minThick, maxThick)
		local nextPoint = if i ~= partsN
			then (CFrame.new(bezier0, bezier1) * CFrame.Angles(0, 0, noise0) * CFrame.Angles(
				math.acos(math.clamp(noiseBetween(input2, input, 2.7, OFFSET_ANGLE, 1), -1, 1)),
				0,
				0
			) * CFrame.new(0, 0, -noise1)).Position
			else bezier1

		if opacity > contractF then
			part.Size = Vector3.new(
				(nextPoint - prevPoint).Magnitude,
				thickness * thicknessNoise * opacity,
				thickness * thicknessNoise * opacity
			)
			part.CFrame = CFrame.lookAt(0.5 * (prevPoint + nextPoint), nextPoint) * X_INVERSE
			part.Transparency = 1 - opacity
		elseif opacity > contractF - 1 / (partsN * fadeLength) then
			local interp = (1 - (opacity - (contractF - 1 / (partsN * fadeLength))) * partsN * fadeLength)
				* (if t1 < timePassed * pulseSpeed - 0.5 * pulseLength then 1 else -1)
			part.Size = Vector3.new(
				(1 - math.abs(interp)) * (nextPoint - prevPoint).Magnitude,
				thickness * thicknessNoise * opacity,
				thickness * thicknessNoise * opacity
			)
			part.CFrame = CFrame.lookAt(
				prevPoint + (nextPoint - prevPoint) * (math.max(0, interp) + 0.5 * (1 - math.abs(interp))),
				nextPoint
			) * X_INVERSE
			part.Transparency = 1 - opacity
		else
			part.Transparency = 1
		end

		if typeof(color) == "Color3" then
			part.Color = color
		else
			t1 = (ranNum + t1 - timePassed * colorOffsetSpeed) % 1

			local keypoints = color.Keypoints
			for _ = 1, #keypoints - 1 do
				if keypoints[i].Time < t1 and t1 < keypoints[i + 1].Time then
					part.Color = keypoints[i].Value:Lerp(
						keypoints[i + 1].Value,
						(t1 - keypoints[i].Time) / (keypoints[i + 1].Time - keypoints[i].Time)
					)
					break
				end
			end
		end

		prevPoint, bezier0 = nextPoint, bezier1
	end
end

--[=[
	@class LightningBolt

	Procedural animated lightning bolt rendered as a chain of neon cylinders
	between two attachments. Construct with `.new`, tune the exposed fields, and
	call `destroy` to remove it. The bolt self-destroys once its pulse completes.
]=]
local LightningBolt = {}

--[=[
	@within LightningBolt
	@param attachment0 BoltAttachment -- the bolt originates here
	@param attachment1 BoltAttachment -- the bolt terminates here
	@param partCount number? -- segment count (defaults to DEFAULT_PART_COUNT)
	@return LightningBolt
]=]
function LightningBolt.new(attachment0: BoltAttachment, attachment1: BoltAttachment, partCount: number?): LightningBolt
	local object = {} :: LightningBolt

	object.enabled = true
	object.attachment0, object.attachment1 = attachment0, attachment1
	object.curveSize0, object.curveSize1 = 0, 0
	object.minRadius, object.maxRadius = 0, 2.4
	object.frequency = 1
	object.animationSpeed = 7
	object.thickness = 1
	object.minThicknessMultiplier, object.maxThicknessMultiplier = 0.2, 1
	object.minTransparency, object.maxTransparency = 0, 1
	object.pulseSpeed = 2
	object.pulseLength = 1000000
	object.fadeLength = 0.2
	object.contractFrom = 0.5
	object.color = Color3.new(1, 1, 1)
	object.colorOffsetSpeed = 3
	object.parts = {}
	object.destroyed = false

	local p0, p1, p2, p3 =
		attachment0.WorldPosition,
		attachment0.WorldPosition + attachment0.WorldAxis * object.curveSize0,
		attachment1.WorldPosition - attachment1.WorldAxis * object.curveSize1,
		attachment1.WorldPosition
	local prevPoint, bezier0 = p0, p0
	local mainBranchN = partCount or DEFAULT_PART_COUNT
	local boltCache = getCache()

	for i = 1, mainBranchN do
		local t1 = i / mainBranchN
		local bezier1 = cubicBezier(p0, p1, p2, p3, t1)
		local nextPoint = if i ~= mainBranchN then CFrame.lookAt(bezier0, bezier1).Position else bezier1
		local boltCFrame = CFrame.lookAt(0.5 * (prevPoint + nextPoint), nextPoint) * X_INVERSE
		local part = boltCache:getPart(boltCFrame)
		part.Size = Vector3.new((nextPoint - prevPoint).Magnitude, 0, 0)
		part.Transparency = 1
		object.parts[i] = part
		prevPoint, bezier0 = nextPoint, bezier1
	end

	object.partsHidden = false
	object.disabledTransparency = 1
	object.startT = os.clock()
	object.ranNum = math.random() * 100
	nextBoltId += 1
	object.refIndex = nextBoltId

	function object:destroy()
		if self.destroyed then
			return
		end

		self.destroyed = true
		activeBolts[self.refIndex] = nil

		for i = 1, #self.parts do
			boltCache:returnPart(self.parts[i])
		end
	end

	activeBolts[object.refIndex] = object

	return object
end

RunService.Heartbeat:Connect(function()
	for _, branch in activeBolts do
		stepBolt(branch)
	end
end)

return LightningBolt

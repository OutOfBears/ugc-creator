local RunService = game:GetService("RunService")

local LightningBolt = require("../LightningBolt")

local SPARK_OPACITY_THRESHOLD = 0.3

export type LightningSparks = {
	-- vars
	enabled: boolean,
	lightningBolt: LightningBolt.LightningBolt,
	maxSparkCount: number,
	minSpeed: number,
	maxSpeed: number,
	minDistance: number,
	maxDistance: number,
	minPartsPerSpark: number,
	maxPartsPerSpark: number,
	sparksN: number,
	slotTable: { [number]: LightningBolt.LightningBolt },
	refIndex: number,

	-- methods
	destroy: (self: LightningSparks) -> (),
}

local activeSparks: { [number]: LightningSparks } = {}
local rng = Random.new()

local function randomVectorOffset(v: Vector3, maxAngle: number): Vector3
	return (CFrame.lookAt(Vector3.zero, v) * CFrame.Angles(0, 0, rng:NextNumber(0, 2 * math.pi)) * CFrame.Angles(
		math.acos(rng:NextNumber(math.cos(maxAngle), 1)),
		0,
		0
	)).LookVector
end

--[=[
	@class LightningSparks

	Spawns short-lived child bolts that fly out of a parent [LightningBolt],
	giving it a crackling, sparking appearance.
]=]
local LightningSparks = {}

--[=[
	@within LightningSparks
	@param bolt LightningBolt -- the bolt sparks fly out of
	@param maxSparks number? -- max sparks alive at once (defaults to 10)
	@return LightningSparks
]=]
function LightningSparks.new(bolt: LightningBolt.LightningBolt, maxSparks: number?): LightningSparks
	local object = {} :: LightningSparks

	object.enabled = true
	object.lightningBolt = bolt
	object.maxSparkCount = maxSparks or 10
	object.minSpeed, object.maxSpeed = 4, 6
	object.minDistance, object.maxDistance = 3, 6
	object.minPartsPerSpark, object.maxPartsPerSpark = 8, 10
	object.sparksN = 0
	object.slotTable = {}
	object.refIndex = #activeSparks + 1

	function object:destroy()
		activeSparks[self.refIndex] = nil

		for i, spark in self.slotTable do
			if spark.destroyed then
				self.slotTable[i] = nil
			end
		end
	end

	activeSparks[object.refIndex] = object

	return object
end

RunService.Heartbeat:Connect(function()
	for _, spark in activeSparks do
		if spark.enabled and spark.sparksN < spark.maxSparkCount then
			local bolt = spark.lightningBolt

			if bolt.destroyed then
				spark:destroy()
				return
			end

			local boltParts = bolt.parts
			local boltPartsN = #boltParts

			local opaqueParts = {}

			for partIndex = 1, boltPartsN do
				if boltParts[partIndex].Transparency < SPARK_OPACITY_THRESHOLD then
					opaqueParts[#opaqueParts + 1] = (partIndex - 0.5) / boltPartsN
				end
			end

			local minSlot, maxSlot

			if #opaqueParts ~= 0 then
				minSlot, maxSlot =
					math.ceil(opaqueParts[1] * spark.maxSparkCount),
					math.ceil(opaqueParts[#opaqueParts] * spark.maxSparkCount)
			end

			for _ = 1, rng:NextInteger(1, spark.maxSparkCount - spark.sparksN) do
				if #opaqueParts == 0 then
					break
				end

				local availableSlots = {}

				for slotIndex = minSlot, maxSlot do
					if spark.slotTable[slotIndex] == nil then
						availableSlots[#availableSlots + 1] = slotIndex
					end
				end

				if #availableSlots ~= 0 then
					local chosenSlot = availableSlots[rng:NextInteger(1, #availableSlots)]
					local localT = rng:NextNumber(-0.5, 0.5)
					local chosenT = (chosenSlot - 0.5 + localT) / spark.maxSparkCount

					local dist, chosenPart = 10, 1

					for opaqueIndex = 1, #opaqueParts do
						local testDist = math.abs(opaqueParts[opaqueIndex] - chosenT)
						if testDist < dist then
							dist, chosenPart = testDist, math.floor((opaqueParts[opaqueIndex] * boltPartsN + 0.5) + 0.5)
						end
					end

					local part = boltParts[chosenPart]

					local a1, a2 = {}, {}
					a1.WorldPosition = part.Position + localT * part.CFrame.RightVector * part.Size.X
					a2.WorldPosition = a1.WorldPosition
						+ randomVectorOffset(part.CFrame.RightVector, math.pi / 4)
							* rng:NextNumber(spark.minDistance, spark.maxDistance)
					a1.WorldAxis = (a2.WorldPosition - a1.WorldPosition).Unit
					a2.WorldAxis = a1.WorldAxis

					local newSpark =
						LightningBolt.new(a1, a2, rng:NextInteger(spark.minPartsPerSpark, spark.maxPartsPerSpark))
					newSpark.minRadius, newSpark.maxRadius = 0, 0.8
					newSpark.animationSpeed = 0
					newSpark.thickness = part.Size.Y / 2
					newSpark.minThicknessMultiplier, newSpark.maxThicknessMultiplier = 1, 1
					newSpark.pulseLength = 0.5
					newSpark.pulseSpeed = rng:NextNumber(spark.minSpeed, spark.maxSpeed)
					newSpark.fadeLength = 0.25

					local cH, _, cV = Color3.toHSV(part.Color)
					newSpark.color = Color3.fromHSV(cH, 0.5, cV)

					spark.slotTable[chosenSlot] = newSpark
				end
			end
		end

		local slotsInUse = 0

		for i, sparkBolt in spark.slotTable do
			if not sparkBolt.destroyed then
				slotsInUse += 1
			else
				spark.slotTable[i] = nil
			end
		end

		spark.sparksN = slotsInUse
	end
end)

return LightningSparks

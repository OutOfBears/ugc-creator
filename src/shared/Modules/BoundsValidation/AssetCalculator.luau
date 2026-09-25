local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoundsConfig = require(ReplicatedStorage.Shared.Data.BoundsConfig)

local EPSILON = 1e-12

export type SimMeshInfo = {
	Verts: { [number]: Vector3 },
	CFrame: CFrame,
}

export type SimMeshInfos = {
	[string]: SimMeshInfo,
}

export type PartsCFrames = {
	[string]: CFrame?,
}

local function floatEquals(a: number, b: number): boolean
	return math.abs(a - b) <= EPSILON
end

local function canBeNormalized(vect: Vector3): boolean
	return (not floatEquals(vect.X, 0)) or (not floatEquals(vect.Y, 0)) or (not floatEquals(vect.Z, 0))
end

local function calculateCFrame(root: Vector3, leaf: Vector3): CFrame?
	local yVector = leaf - root
	if not canBeNormalized(yVector) then
		return nil
	end

	yVector = yVector.Unit

	local xVector = yVector:Cross(Vector3.zAxis).Unit
	if not canBeNormalized(xVector) then
		local crossWith = if yVector.Z < 0 then Vector3.yAxis else -Vector3.yAxis
		xVector = yVector:Cross(crossWith).Unit
	end
	local zVector = xVector:Cross(yVector).Unit

	return CFrame.fromMatrix(Vector3.new(), xVector, yVector, zVector)
end

local function calculateHierarchyTransforms(assetTypeEnum: Enum.AssetType, assetParts: SimMeshInfos): PartsCFrames
	local partsHierarchyOrder = BoundsConfig.enumToPartsMap[assetTypeEnum]
	local rootPart = assetParts[partsHierarchyOrder[1]]
	local results = {} :: PartsCFrames
	for index, partName in partsHierarchyOrder do
		if index == 1 then
			results[partName] = CFrame.new()
			continue
		end

		local currentPart = assetParts[partName]
		results[partName] = rootPart.CFrame:inverse() * currentPart.CFrame
	end

	return results
end

--[=[
	@class AssetCalculator

	Works out where each mesh part of a body asset sits relative to the asset's root part, and
	how far a limb has to be rotated to reach the I-pose the bounds are measured in.
]=]

--[=[
	@within AssetCalculator
	@param partsCFrames PartsCFrames -- the parts' current transforms, relative to the root part
	@param assetTypeEnum Enum.AssetType -- the limb being straightened
	@param assetParts SimMeshInfos -- every simulated mesh of the asset, keyed by part name
	@return PartsCFrames -- the same parts, rotated so root-to-leaf runs along the world Y axis
]=]
local function calculateStraightenedLimb(
	partsCFrames: PartsCFrames,
	assetTypeEnum: Enum.AssetType,
	assetParts: SimMeshInfos
): PartsCFrames
	local partsHierarchyOrder = BoundsConfig.enumToPartsMap[assetTypeEnum]
	local rootPart = assetParts[partsHierarchyOrder[1]]
	local leafPart = assetParts[partsHierarchyOrder[#partsHierarchyOrder]]
	local transform = calculateCFrame(rootPart.CFrame.Position, leafPart.CFrame.Position)

	local result = {} :: PartsCFrames
	for part, cframe in partsCFrames do
		result[part] = transform:inverse() * cframe
	end

	return result
end

--[=[
	@within AssetCalculator
	@param assetTypeEnum Enum.AssetType -- the body asset being measured
	@param assetParts SimMeshInfos -- every simulated mesh of the asset, keyed by part name
	@return PartsCFrames -- each part's transform relative to the asset's root part
]=]
local function calculateAllTransformsForAsset(assetTypeEnum: Enum.AssetType, assetParts: SimMeshInfos): PartsCFrames
	if Enum.AssetType.DynamicHead == assetTypeEnum then
		return {
			Head = CFrame.new(),
		}
	end

	return calculateHierarchyTransforms(assetTypeEnum, assetParts)
end

return {
	calculateStraightenedLimb = calculateStraightenedLimb,
	calculateAllTransformsForAsset = calculateAllTransformsForAsset,
}

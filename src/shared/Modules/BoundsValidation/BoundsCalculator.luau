local AssetBoundingBox = require("./AssetBoundingBox")
local AssetCalculator = require("./AssetCalculator")

export type SimMeshInfo = AssetCalculator.SimMeshInfo
export type SimMeshInfos = AssetCalculator.SimMeshInfos

local function orientSingleAssetToWorldAxes(
	partsCFrames: AssetCalculator.PartsCFrames,
	assetTypeEnum: Enum.AssetType,
	assetParts: AssetCalculator.SimMeshInfos
)
	if
		assetTypeEnum ~= Enum.AssetType.LeftArm
		and assetTypeEnum ~= Enum.AssetType.RightArm
		and assetTypeEnum ~= Enum.AssetType.LeftLeg
		and assetTypeEnum ~= Enum.AssetType.RightLeg
	then
		return
	end

	local results = AssetCalculator.calculateStraightenedLimb(partsCFrames, assetTypeEnum, assetParts)

	for name, newCFrame in results do
		partsCFrames[name] = newCFrame
	end
end

local function calculateBoundsDataForPart(
	meshPartInfo: AssetCalculator.SimMeshInfo,
	cframe: CFrame
): AssetBoundingBox.AssetBoundingBox
	local verts = meshPartInfo.Verts
	local boundingBoxForPart = AssetBoundingBox()
	for _, vertPos in verts do
		boundingBoxForPart:expand(cframe:PointToWorldSpace(vertPos))
	end

	return boundingBoxForPart
end

local function calculateAllPartsBoundsData(
	partsCFrames: AssetCalculator.PartsCFrames,
	assetParts: AssetCalculator.SimMeshInfos
): { [string]: AssetBoundingBox.AssetBoundingBox }
	local result = {}
	for partName, cframe in partsCFrames do
		result[partName] = calculateBoundsDataForPart(assetParts[partName], cframe)
	end
	return result
end

local function calculateTotalBoundsForAsset(
	partsCFrames: AssetCalculator.PartsCFrames,
	assetParts: AssetCalculator.SimMeshInfos
): AssetBoundingBox.AssetBoundingBox
	local allPartsBoundsData = calculateAllPartsBoundsData(partsCFrames, assetParts)
	local overallBounds = AssetBoundingBox()
	for _, boundingBoxForPart in allPartsBoundsData do
		overallBounds:combine(boundingBoxForPart)
	end
	return overallBounds
end

--[=[
	@class BoundsCalculator

	Measures the combined bounding box of every mesh making up a body asset. Arms and legs are
	straightened to the I-pose first, so a bent limb is not measured along its diagonal.
]=]

--[=[
	@within BoundsCalculator
	@param assetTypeEnum Enum.AssetType -- the body asset being measured
	@param assetParts SimMeshInfos -- every simulated mesh of the asset, keyed by part name
	@return AssetBoundingBox -- the asset's combined bounds
]=]
local function calculateAssetBounds(
	assetTypeEnum: Enum.AssetType,
	assetParts: AssetCalculator.SimMeshInfos
): AssetBoundingBox.AssetBoundingBox
	if assetTypeEnum == Enum.AssetType.DynamicHead then
		return calculateTotalBoundsForAsset({ Head = CFrame.new() }, assetParts)
	end

	local partsCFrames = AssetCalculator.calculateAllTransformsForAsset(assetTypeEnum, assetParts)

	orientSingleAssetToWorldAxes(partsCFrames, assetTypeEnum, assetParts)

	return calculateTotalBoundsForAsset(partsCFrames, assetParts)
end

return {
	calculateAssetBounds = calculateAssetBounds,
}

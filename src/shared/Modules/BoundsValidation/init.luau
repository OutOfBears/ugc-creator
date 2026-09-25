local AvatarCreationService = game:GetService("AvatarCreationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetBoundingBox = require("./BoundsValidation/AssetBoundingBox")
local BoundsCalculator = require("./BoundsValidation/BoundsCalculator")
local BoundsConfig = require(ReplicatedStorage.Shared.Data.BoundsConfig)

local DIMENSIONS = { "X", "Y", "Z" }

export type SimMeshInfo = BoundsCalculator.SimMeshInfo
export type SimMeshInfos = BoundsCalculator.SimMeshInfos

export type OutOfBoundsData = {
	assetTypeEnum: Enum.AssetType,
	size: Vector3,
	originalSize: Vector3,
	minSize: Vector3,
	maxSize: Vector3,
}

type BoundsLimits = {
	MinSize: Vector3,
	MaxSize: Vector3,
}

type BodyPartRules = {
	[Enum.AssetType]: {
		Bounds: { [string]: BoundsLimits },
	},
}

local bodyPartRules: BodyPartRules? = nil

local function getBodyPartRules(): BodyPartRules
	local rules = bodyPartRules
	if not rules then
		rules = AvatarCreationService:GetValidationRules().BodyPartRules
		bodyPartRules = rules
	end

	return rules :: BodyPartRules
end

local function validateBoundingBox(
	assetTypeEnum: Enum.AssetType,
	scaleTypeKey: string,
	originalAssetBoundingBox: AssetBoundingBox.AssetBoundingBox,
	assetBoundingBox: AssetBoundingBox.AssetBoundingBox
)
	local boundsLimits = getBodyPartRules()[assetTypeEnum].Bounds[scaleTypeKey]
	local assetSize = assetBoundingBox:extent()
	local boundsInfo = {
		assetTypeEnum = assetTypeEnum,
		size = assetSize,
		originalSize = originalAssetBoundingBox:extent(),
		minSize = boundsLimits.MinSize,
		maxSize = boundsLimits.MaxSize,
	} :: OutOfBoundsData

	for _, dimension in DIMENSIONS do
		local assetSizeOnAxis = assetSize[dimension]
		local minSizeOnAxis = boundsLimits.MinSize[dimension] / BoundsConfig.boundsPadding
		local maxSizeOnAxis = boundsLimits.MaxSize[dimension] * BoundsConfig.boundsPadding

		if assetSizeOnAxis < minSizeOnAxis then
			return false,
				boundsInfo,
				string.format(
					"Asset size for %s is too small. Asset size is (%.2f, %.2f, %.2f) but the minimum asset size is (%s)",
					assetTypeEnum.Name,
					assetSize.X,
					assetSize.Y,
					assetSize.Z,
					tostring(boundsLimits.MinSize)
				)
		end

		if assetSizeOnAxis > maxSizeOnAxis then
			return false,
				boundsInfo,
				string.format(
					"Asset size for %s is too big. Asset size is (%.2f, %.2f, %.2f) but the maximum asset size is (%s)",
					assetTypeEnum.Name,
					assetSize.X,
					assetSize.Y,
					assetSize.Z,
					tostring(boundsLimits.MaxSize)
				)
		end
	end

	return true
end

--[=[
	@class BoundsValidation

	Checks that a deformed body asset still fits inside the UGC size limits Roblox validates
	against on publish, so the editor can flag an over-sized limb before the upload is rejected.

	The rules come from `AvatarCreationService:GetValidationRules()` on first use and are cached
	for the lifetime of the session.
]=]

--[=[
	@within BoundsValidation
	@param initialMeshInfo SimMeshInfos -- the asset's meshes before any deformation
	@param deformedMeshInfo SimMeshInfos -- the asset's meshes as they stand now
	@param deformsPartNames { string } -- the parts that were deformed
	@return { OutOfBoundsData } -- one entry per asset that no longer fits, empty when everything passes
]=]
local function validateBounds(
	initialMeshInfo: SimMeshInfos,
	deformedMeshInfo: SimMeshInfos,
	deformsPartNames: { string }
): { OutOfBoundsData }
	local errorBoundsInfos = {}
	for _, deformedPartName in deformsPartNames do
		local assetTypeEnum = BoundsConfig.partToEnumMap[deformedPartName]
		local originalAssetBoundingBox = BoundsCalculator.calculateAssetBounds(assetTypeEnum, initialMeshInfo)
		local assetBoundingBox = BoundsCalculator.calculateAssetBounds(assetTypeEnum, deformedMeshInfo)
		local success, errorBoundsInfo, _errorMessage =
			validateBoundingBox(assetTypeEnum, BoundsConfig.scaleType, originalAssetBoundingBox, assetBoundingBox)
		if not success then
			table.insert(errorBoundsInfos, errorBoundsInfo)
		end
	end

	return errorBoundsInfos
end

return {
	validateBounds = validateBounds,
}

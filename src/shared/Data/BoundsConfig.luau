export type BoundsConfig = {
	scaleType: string,
	boundsPadding: number,
	partToEnumMap: { [string]: Enum.AssetType },
	enumToPartsMap: { [Enum.AssetType]: { string } },
}

--[=[
	@class BoundsConfig

	Maps avatar mesh parts to the asset type whose validation bounds they must fit inside, and back
	again. `enumToPartsMap` lists parts in hierarchy order; `boundsPadding` shrinks the allowed
	volume so a creation clears the limit with room to spare.
]=]
local config: BoundsConfig = {
	scaleType = "ProportionsNormal",

	boundsPadding = 0.8,

	partToEnumMap = {
		Head = Enum.AssetType.DynamicHead,
		UpperTorso = Enum.AssetType.Torso,
		LowerTorso = Enum.AssetType.Torso,
		LeftHand = Enum.AssetType.LeftArm,
		LeftLowerArm = Enum.AssetType.LeftArm,
		LeftUpperArm = Enum.AssetType.LeftArm,
		RightHand = Enum.AssetType.RightArm,
		RightLowerArm = Enum.AssetType.RightArm,
		RightUpperArm = Enum.AssetType.RightArm,
		LeftFoot = Enum.AssetType.LeftLeg,
		LeftLowerLeg = Enum.AssetType.LeftLeg,
		LeftUpperLeg = Enum.AssetType.LeftLeg,
		RightFoot = Enum.AssetType.RightLeg,
		RightLowerLeg = Enum.AssetType.RightLeg,
		RightUpperLeg = Enum.AssetType.RightLeg,
	},

	enumToPartsMap = {
		[Enum.AssetType.DynamicHead] = { "Head" },
		[Enum.AssetType.Torso] = { "LowerTorso", "UpperTorso" },
		[Enum.AssetType.LeftArm] = { "LeftUpperArm", "LeftLowerArm", "LeftHand" },
		[Enum.AssetType.RightArm] = { "RightUpperArm", "RightLowerArm", "RightHand" },
		[Enum.AssetType.LeftLeg] = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
		[Enum.AssetType.RightLeg] = { "RightUpperLeg", "RightLowerLeg", "RightFoot" },
	},
}

table.freeze(config)

return config

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetUtil = require(ReplicatedStorage.Shared.Modules.Utils.AssetUtil)
local CreationConfig = require("./CreationConfig")
local RegionMaps = require("./RegionMaps")

export type BlankDefinition = {
	name: string,
	creationType: string,
	avatarAssetType: Enum.AvatarAssetType?,

	enableYRotation: boolean?,
	enableWidgetMeshEditing: boolean?,
	enableKitbashing: boolean?,
	enableStickerPatterning: boolean?,
	enableRegionalStickerPatterning: boolean?,

	layerCatalogName: string?,
	accessoryCatalogName: string?,

	initialYaw: number?,
	initialZOffset: number,
	previewScale: number?,

	regionMapSubParts: RegionMaps.RegionMap?,
	regionMapIndividual: RegionMaps.RegionMap?,
}

export type Blank = BlankDefinition & {
	sourceModel: Model,
	meshEditControlGroups: Folder,
	individualPartsNames: { [string]: boolean },
}

local DEFINITIONS: { BlankDefinition } = {
	{
		name = "RobotModel",
		creationType = CreationConfig.creationTypes.body,
		enableWidgetMeshEditing = true,
		enableStickerPatterning = true,
		enableRegionalStickerPatterning = true,

		initialZOffset = 2,

		regionMapSubParts = RegionMaps.RobotSubParts,
		regionMapIndividual = RegionMaps.RobotIndividualParts,
	},
	{
		name = "TShirtModel",
		creationType = CreationConfig.creationTypes.accessory,
		avatarAssetType = Enum.AvatarAssetType.TShirtAccessory,
		enableStickerPatterning = true,
		enableRegionalStickerPatterning = true,
		enableWidgetMeshEditing = true,
		enableKitbashing = true,

		initialZOffset = 2,

		regionMapSubParts = RegionMaps.TShirtSubParts,
		regionMapIndividual = RegionMaps.TShirtIndividualParts,
	},
	{
		name = "HatModel",
		creationType = CreationConfig.creationTypes.accessory,
		avatarAssetType = Enum.AvatarAssetType.Hat,
		enableYRotation = true,
		enableStickerPatterning = true,
		enableRegionalStickerPatterning = true,
		enableKitbashing = true,

		initialZOffset = 2,
		previewScale = 1.2,

		regionMapSubParts = RegionMaps.HatSubParts,
		regionMapIndividual = RegionMaps.HatIndividualParts,
	},
	{
		name = "FoxModel",
		creationType = CreationConfig.creationTypes.body,
		avatarAssetType = Enum.AvatarAssetType.Hat,
		layerCatalogName = "Fox",
		accessoryCatalogName = "Fox",

		initialYaw = 90,
		initialZOffset = 2,
	},
}

local AVATAR_ASSET_TYPE_TO_ACCESSORY_TYPE = {
	[Enum.AvatarAssetType.Hat] = Enum.AccessoryType.Hat,
	[Enum.AvatarAssetType.TShirtAccessory] = Enum.AccessoryType.TShirt,
	[Enum.AvatarAssetType.JacketAccessory] = Enum.AccessoryType.Jacket,
	[Enum.AvatarAssetType.PantsAccessory] = Enum.AccessoryType.Pants,
	[Enum.AvatarAssetType.ShirtAccessory] = Enum.AccessoryType.Shirt,
	[Enum.AvatarAssetType.DressSkirtAccessory] = Enum.AccessoryType.DressSkirt,
	[Enum.AvatarAssetType.SweaterAccessory] = Enum.AccessoryType.Sweater,
	[Enum.AvatarAssetType.ShortsAccessory] = Enum.AccessoryType.Shorts,
	[Enum.AvatarAssetType.BackAccessory] = Enum.AccessoryType.Back,
	[Enum.AvatarAssetType.FaceAccessory] = Enum.AccessoryType.Face,
	[Enum.AvatarAssetType.NeckAccessory] = Enum.AccessoryType.Neck,
	[Enum.AvatarAssetType.WaistAccessory] = Enum.AccessoryType.Waist,
	[Enum.AvatarAssetType.FrontAccessory] = Enum.AccessoryType.Front,
	[Enum.AvatarAssetType.HairAccessory] = Enum.AccessoryType.Hair,
}

local resolved: { [string]: Blank } = {}

local function individualPartNames(regionMap: RegionMaps.RegionMap?): { [string]: boolean }
	local names = {}

	if regionMap then
		for _, region in regionMap do
			names[region.name] = true
		end
	end

	return names
end

local function meshPartNamesFromModel(model: Model): { [string]: boolean }
	local names = {}

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("MeshPart") and descendant.Name ~= "PrimaryPart" then
			names[descendant.Name] = true
		end
	end

	return names
end

local function assertAccessoryShape(definition: BlankDefinition, sourceModel: Model)
	local accessory = sourceModel:FindFirstChildWhichIsA("Accessory")
	assert(accessory, `Accessory blank '{definition.name}' is missing an Accessory instance.`)
	assert(
		accessory.AccessoryType ~= Enum.AccessoryType.Unknown,
		`Accessory blank '{definition.name}' has AccessoryType set to Unknown.`
	)

	local expected = AVATAR_ASSET_TYPE_TO_ACCESSORY_TYPE[definition.avatarAssetType]
	assert(
		accessory.AccessoryType == expected,
		`Accessory blank '{definition.name}' has AccessoryType {accessory.AccessoryType} but expected {expected}.`
	)
end

--[=[
	@class Blanks

	The starting models a player can edit — one body (`RobotModel`) and two accessories
	(`TShirtModel`, `HatModel`).

	Each definition is static, but the instances it points at live in the place:
	`ReplicatedStorage.Assets.Blanks.<name>` and `ReplicatedStorage.Assets.MeshEditControlGroups.<name>`.
	Those are resolved on first [Blanks.get], not at require time — this module is pulled in
	during the eager `Loader` pass, and yielding on `WaitForChild` there would stall startup.
]=]
local Blanks = {}

--[=[
	@within Blanks
	@yields
	@param name string -- a blank name, e.g. `"RobotModel"`
	@return Blank? -- the blank with its instances resolved, or nil if `name` is unknown

	Resolves a blank and caches it. Yields the first time a given blank is requested while its
	model and mesh-edit control groups replicate. Errors if an accessory blank's `Accessory`
	child is missing or carries the wrong `AccessoryType`.
]=]
function Blanks.get(name: string): Blank?
	local cached = resolved[name]
	if cached then
		return cached
	end

	local definition: BlankDefinition? = nil
	for _, candidate in DEFINITIONS do
		if candidate.name == name then
			definition = candidate
			break
		end
	end

	if not definition then
		return nil
	end

	local sourceModel = AssetUtil.resolve(`Blanks/{definition.name}`) :: Model
	local meshEditControlGroups = AssetUtil.resolve(`MeshEditControlGroups/{definition.name}`) :: Folder

	if definition.creationType == CreationConfig.creationTypes.accessory then
		assertAccessoryShape(definition, sourceModel)
	end

	assert(
		not (definition.enableKitbashing and definition.accessoryCatalogName),
		`Blank '{definition.name}' enables both kitbashing and accessory swapping; they share the atlas cells.`
	)

	local blank: Blank = table.clone(definition) :: any
	blank.sourceModel = sourceModel
	blank.meshEditControlGroups = meshEditControlGroups
	blank.individualPartsNames = if definition.regionMapIndividual
		then individualPartNames(definition.regionMapIndividual)
		else meshPartNamesFromModel(sourceModel)

	resolved[name] = blank

	return blank
end

--[=[
	@within Blanks
	@param definition BlankDefinition -- the blank to check
	@return boolean -- true if its color map is a kitbash atlas (own texture in the top-left cell)
]=]
function Blanks.usesAtlas(definition: BlankDefinition): boolean
	return definition.enableKitbashing == true or definition.accessoryCatalogName ~= nil
end

--[=[
	@within Blanks
	@return { BlankDefinition } -- every blank definition, in editor display order

	Returns the definitions without resolving their instances — use this for menus and icons,
	and [Blanks.get] once the player has actually picked one.
]=]
function Blanks.all(): { BlankDefinition }
	return DEFINITIONS
end

return Blanks

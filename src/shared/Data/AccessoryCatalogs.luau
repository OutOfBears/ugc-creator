local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorLayers = require(ReplicatedStorage.Shared.Data.ColorLayers)

export type AccessoryOption = {
	name: string,
	thumbnail: string,
	meshId: string,
	offset: CFrame?,
	scale: number?,
	colors: ColorLayers.Catalog,
}

export type AccessorySlot = {
	name: string,
	atlasSlot: number,
	optional: boolean?,
	options: { AccessoryOption },
}

export type AccessoryCatalog = {
	slots: { AccessorySlot },
}

export type AccessoryCatalogs = { [string]: AccessoryCatalog }

local function singleLayer(sectionName: string, textureId: string): ColorLayers.Catalog
	return {
		sortOrder = { sectionName },
		layers = { { name = sectionName, textureId = textureId } },
		variantGroups = {},
	}
end

--[=[
	@class AccessoryCatalogs

	The swappable accessories per head base, keyed by the blank's `accessoryCatalogName`. Each slot
	(ears, horns, …) owns one cell of the kitbash atlas (`atlasSlot`, an index into
	`CreationConfig.atlasSlots`), so a head has at most three slots. The selected option's mesh is
	merged into the head at `offset` (head space, default identity) and `scale`, and its `colors`
	catalog is baked into the slot's atlas cell. An `optional` slot may be left empty.
]=]
local catalogs: AccessoryCatalogs = {
	-- PLACEHOLDER: stand-in meshes and textures from `Assets.KitbashPieces` until the earless Fox
	-- head and its ear sets are delivered; replace the options wholesale when they land.
	Fox = {
		slots = {
			{
				name = "Ears",
				atlasSlot = 1,
				options = {
					{
						name = "Spike",
						thumbnail = "rbxthumb://type=Asset&id=73708733249009&w=420&h=420",
						meshId = "rbxassetid://72011096401946",
						offset = CFrame.new(0, 1.05, 0),
						scale = 4,
						colors = singleLayer("Fur", "rbxassetid://81277363065633"),
					},
					{
						name = "GooglyEye",
						thumbnail = "rbxthumb://type=Asset&id=82309817363385&w=420&h=420",
						meshId = "rbxassetid://86937460855276",
						offset = CFrame.new(0, 1.05, 0) * CFrame.Angles(math.rad(-90), 0, 0),
						scale = 2,
						colors = singleLayer("Fur", "rbxassetid://94458733362413"),
					},
				},
			},
			{
				name = "Horns",
				atlasSlot = 2,
				optional = true,
				options = {
					{
						name = "RedGemstone",
						thumbnail = "rbxthumb://type=Asset&id=88619907280627&w=420&h=420",
						meshId = "rbxassetid://111061276922139",
						offset = CFrame.new(0, 0.4, -1.05),
						scale = 2,
						colors = singleLayer("Gem", "rbxassetid://78556304979048"),
					},
				},
			},
		},
	},
}

table.freeze(catalogs)

return catalogs

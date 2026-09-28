local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorLayers = require(ReplicatedStorage.Shared.Data.ColorLayers)
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)

export type LayerDecalPreview = {
	-- vars
	target: BasePart,
	proxy: Part,
	catalog: ColorLayers.Catalog,
	maid: Maid.Maid,
	-- methods
	setSectionColor: (self: LayerDecalPreview, name: string, color: Color3, alpha: number) -> (),
	selectVariant: (self: LayerDecalPreview, groupName: string, optionIndex: number) -> (),
	setPaintImages: (self: LayerDecalPreview, images: { EditableImage }) -> (),
	destroy: (self: LayerDecalPreview) -> (),
}

--[=[
	@class LayerDecalPreview

	The fast, live-scrubbing render path: one tinted `Decal` per catalog section stacked by
	`sortOrder`, recolored instantly through `Decal.Color3`/`Transparency` with no buffer work. Variant
	groups (e.g. the mouth) stack their options too, toggling `Transparency` to show one at a time. Use
	this while the player adjusts colors, then bake with [LayerColorCompositor] on commit.

	Decals on a MeshPart project flat onto one face, but decals on a part with a FileMesh
	`SpecialMesh` wrap by the mesh's UVs. So the decals live on an invisible proxy part carrying the
	source mesh, sat over `target` inside its model so it follows the model's rotation. Paint images
	(brush strokes and stickers) are stacked as the topmost decals via `setPaintImages`.
]=]
local function LayerDecalPreview(
	target: BasePart,
	sourceMeshPart: MeshPart,
	catalog: ColorLayers.Catalog
): LayerDecalPreview
	local maid = Maid.new()
	local object = {} :: LayerDecalPreview

	object.target = target
	object.catalog = catalog
	object.maid = maid

	object.proxy = maid:add(Create("Part", {
		Name = "LayerDecalPreview",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = target.Size,
		CFrame = target.CFrame,
		Children = {
			Create("SpecialMesh", {
				MeshType = Enum.MeshType.FileMesh,
				MeshId = sourceMeshPart.MeshId,
				Scale = target.Size / sourceMeshPart.MeshSize,
			}),
		},
		Parent = target.Parent,
	}) :: Part)

	local sectionDecals: { [string]: Decal } = {}
	local variantDecals: { [string]: { Decal } } = {}

	local zIndex = 0
	local function addDecal(name: string, textureId: string): Decal
		local decal = Create("Decal", {
			Name = `{zIndex}_{name}`,
			Texture = textureId,
			ZIndex = zIndex,
			Parent = object.proxy,
		})
		zIndex += 1
		maid:add(decal)

		return decal
	end

	local layersByName: { [string]: ColorLayers.Layer } = {}
	for _, layer in catalog.layers do
		layersByName[layer.name] = layer
	end

	for _, layerName in catalog.sortOrder do
		local layer = layersByName[layerName]
		if layer then
			sectionDecals[layerName] = addDecal(layerName, layer.textureId)
		end
	end

	for _, group in catalog.variantGroups do
		local decals = {}
		for optionIndex, groupOption in group.options do
			local decal = addDecal(`{group.name}_{groupOption.name}`, groupOption.textureId)
			decal.Transparency = if optionIndex == 1 then 0 else 1
			decals[optionIndex] = decal
		end
		variantDecals[group.name] = decals
	end

	local paintDecals: { Decal } = {}

	--[=[
		@within LayerDecalPreview
		@param name string -- section (or variant group) name to tint
		@param color Color3 -- tint applied to the decal
		@param alpha number -- transparency, 0 opaque to 1 hidden
	]=]
	function object:setSectionColor(name: string, color: Color3, alpha: number)
		local decal = sectionDecals[name]
		if decal then
			decal.Color3 = color
			decal.Transparency = alpha
		end
	end

	--[=[
		@within LayerDecalPreview
		@param groupName string -- the variant group to switch
		@param optionIndex number -- the 1-based option to show; the rest are hidden
	]=]
	function object:selectVariant(groupName: string, optionIndex: number)
		local decals = variantDecals[groupName]
		if not decals then
			return
		end

		for index, decal in decals do
			decal.Transparency = if index == optionIndex then 0 else 1
		end
	end

	--[=[
		@within LayerDecalPreview
		@param images { EditableImage } -- paint images to show above the sections, bottom to top
	]=]
	function object:setPaintImages(images: { EditableImage })
		for index, image in images do
			local decal = paintDecals[index]
			if not decal then
				decal = addDecal(`Paint{index}`, "")
				paintDecals[index] = decal
			end
			decal.TextureContent = Content.fromObject(image)
		end

		for index = #paintDecals, #images + 1, -1 do
			paintDecals[index]:Destroy()
			paintDecals[index] = nil
			zIndex -= 1
		end
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return LayerDecalPreview

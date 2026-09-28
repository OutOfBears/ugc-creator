local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ColorLayers = require(ReplicatedStorage.Shared.Data.ColorLayers)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local TextureUtils = require(ReplicatedStorage.Shared.Modules.Utils.TextureUtils)

local DEFAULT_RESOLUTION = Vector2.one * 1024

export type SectionColor = {
	color: Color3,
	alpha: number,
}

export type SectionColors = { [string]: SectionColor }
export type VariantSelections = { [string]: number }

type CachedImage = {
	buffer: buffer,
	size: Vector2,
	position: Vector2,
}

export type LayerColorCompositor = {
	-- vars
	catalog: ColorLayers.Catalog,
	maid: Maid.Maid,
	-- methods
	compose: (
		self: LayerColorCompositor,
		sectionColors: SectionColors,
		variantSelections: VariantSelections,
		overlay: EditableImage?
	) -> EditableImage,
	composeInto: (
		self: LayerColorCompositor,
		target: EditableImage,
		origin: Vector2,
		sectionColors: SectionColors,
		variantSelections: VariantSelections,
		keyPrefix: string?
	) -> (),
	getEditableImage: (self: LayerColorCompositor) -> EditableImage,
	destroy: (self: LayerColorCompositor) -> (),
}

local function getOpaqueBounds(size: Vector2, pixels: buffer): (Vector2, Vector2)
	local width, height = size.X, size.Y

	local minX, minY = width, height
	local maxX, maxY = -1, -1

	for y = 0, height - 1 do
		local row = y * width * 4
		for x = 0, width - 1 do
			if buffer.readu8(pixels, row + x * 4 + 3) ~= 0 then
				if x < minX then
					minX = x
				end
				if x > maxX then
					maxX = x
				end
				if y < minY then
					minY = y
				end
				if y > maxY then
					maxY = y
				end
			end
		end
	end

	if maxX < 0 then
		return Vector2.zero, Vector2.zero
	end

	return Vector2.new(minX, minY), Vector2.new(maxX - minX + 1, maxY - minY + 1)
end

--[=[
	@class LayerColorCompositor

	Composites a stack of tinted section PNGs into one EditableImage. Each section is drawn in the
	catalog's `sortOrder`, tinted by its chosen color and skipped when fully transparent; one option
	per variant group (e.g. the mouth) is drawn on top. Every source PNG is preloaded once, resampled
	to `resolution` when its size differs, and cached cropped to its opaque bounds, so composing only
	touches pixels that matter.
]=]
local function LayerColorCompositor(catalog: ColorLayers.Catalog, resolution: Vector2?): LayerColorCompositor
	local maid = Maid.new()
	local object = {} :: LayerColorCompositor

	object.catalog = catalog
	object.maid = maid

	local canvasSize = resolution or DEFAULT_RESOLUTION
	local cache: { [string]: CachedImage } = {}

	local layersByName: { [string]: ColorLayers.Layer } = {}
	for _, layer in catalog.layers do
		layersByName[layer.name] = layer
	end

	local function throwMemoryError()
		maid:doCleaning()
		table.clear(cache)
		error(CreationStrings.failedToCreateImage)
	end

	local function cacheImage(textureId: string)
		if cache[textureId] then
			return
		end

		local sourceImage = AssetService:CreateEditableImageAsync(Content.fromUri(textureId))
		if not sourceImage then
			throwMemoryError()
			return
		end

		if sourceImage.Size ~= canvasSize then
			local resampled = AssetService:CreateEditableImage({ Size = canvasSize })
			if not resampled then
				sourceImage:Destroy()
				throwMemoryError()
				return
			end

			resampled:DrawImageTransformed(canvasSize / 2, canvasSize / sourceImage.Size, 0, sourceImage)
			sourceImage:Destroy()
			sourceImage = resampled
		end

		local fullPixels = sourceImage:ReadPixelsBuffer(Vector2.zero, sourceImage.Size)
		local position, size = getOpaqueBounds(sourceImage.Size, fullPixels)

		if size.X == 0 or size.Y == 0 then
			cache[textureId] = { buffer = buffer.create(0), size = size, position = position }
		else
			cache[textureId] = {
				buffer = sourceImage:ReadPixelsBuffer(position, size),
				size = size,
				position = position,
			}
		end

		sourceImage:Destroy()
	end

	for _, layer in catalog.layers do
		cacheImage(layer.textureId)
	end
	for _, group in catalog.variantGroups do
		for _, groupOption in group.options do
			cacheImage(groupOption.textureId)
		end
	end

	local sharedImage: EditableImage? = nil
	local sharedBuffer = buffer.create(canvasSize.X * canvasSize.Y * 4)

	local function getSharedImage(): EditableImage
		if not sharedImage then
			sharedImage = AssetService:CreateEditableImage({ Size = canvasSize })
			if not sharedImage then
				throwMemoryError()
			end
			maid:add(sharedImage)
		end

		return sharedImage :: EditableImage
	end

	local function drawSection(textureId: string, color: Color3)
		local cached = cache[textureId]
		if not cached or cached.size.X == 0 then
			return
		end

		TextureUtils.blitTintedAlphaOver(sharedBuffer, canvasSize.X, cached.buffer, cached.size, cached.position, color)
	end

	local function paint(
		sectionColors: SectionColors,
		variantSelections: VariantSelections,
		keyPrefix: string,
		background: number
	)
		buffer.fill(sharedBuffer, 0, background)

		for _, layerName in catalog.sortOrder do
			local layer = layersByName[layerName]
			if not layer then
				continue
			end

			local sectionColor = sectionColors[keyPrefix .. layerName]
			if sectionColor and sectionColor.alpha >= 1 then
				continue
			end

			drawSection(layer.textureId, if sectionColor then sectionColor.color else Color3.new(1, 1, 1))
		end

		for _, group in catalog.variantGroups do
			local selectedIndex = variantSelections[keyPrefix .. group.name] or 1
			local groupOption = group.options[selectedIndex]
			if not groupOption then
				continue
			end

			local sectionColor = sectionColors[keyPrefix .. group.name]
			if sectionColor and sectionColor.alpha >= 1 then
				continue
			end

			drawSection(groupOption.textureId, if sectionColor then sectionColor.color else Color3.new(1, 1, 1))
		end
	end

	--[=[
		@within LayerColorCompositor
		@param sectionColors { [string]: { color: Color3, alpha: number } } -- color and alpha per section/group name
		@param variantSelections { [string]: number } -- chosen option index per variant group name
		@param overlay EditableImage? -- drawn over everything, scaled to the canvas (e.g. brush and sticker paint)
		@return EditableImage -- the shared image, repainted in place

		Repaints the shared image from scratch: clears it, draws each section in `sortOrder` tinted by
		its color (skipping fully transparent ones), then the selected option of each variant group,
		then `overlay` on top. A section or group with no entry in `sectionColors` is drawn untinted.
	]=]
	function object:compose(
		sectionColors: SectionColors,
		variantSelections: VariantSelections,
		overlay: EditableImage?
	): EditableImage
		paint(sectionColors, variantSelections, "", 0)

		local image = getSharedImage()
		image:WritePixelsBuffer(Vector2.zero, canvasSize, sharedBuffer)

		if overlay then
			image:DrawImageTransformed(canvasSize / 2, canvasSize / overlay.Size, 0, overlay, {
				CombineType = Enum.ImageCombineType.BlendSourceOver,
			})
		end

		return image
	end

	--[=[
		@within LayerColorCompositor
		@param target EditableImage -- the image to paint into, e.g. a creation's base atlas
		@param origin Vector2 -- top-left pixel of the `resolution`-sized cell to overwrite
		@param sectionColors { [string]: { color: Color3, alpha: number } } -- color and alpha per section/group key
		@param variantSelections { [string]: number } -- chosen option index per variant group key
		@param keyPrefix string? -- prepended to section and group names when reading the two maps

		Overwrites one cell of `target` with the composed layers over an opaque white background, the
		same fill a normal blank's color map starts from.
	]=]
	function object:composeInto(
		target: EditableImage,
		origin: Vector2,
		sectionColors: SectionColors,
		variantSelections: VariantSelections,
		keyPrefix: string?
	)
		paint(sectionColors, variantSelections, keyPrefix or "", 255)
		target:WritePixelsBuffer(origin, canvasSize, sharedBuffer)
	end

	--[=[
		@within LayerColorCompositor
		@return EditableImage -- the shared composite image
	]=]
	function object:getEditableImage(): EditableImage
		return getSharedImage()
	end

	function object:destroy()
		maid:doCleaning()
		table.clear(cache)
	end

	return object
end

return LayerColorCompositor

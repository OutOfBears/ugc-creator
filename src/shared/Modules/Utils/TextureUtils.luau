--[=[
	@class TextureUtils

	EditableImage helpers shared by every paint action: layer clearing, brush stamping, region
	stencilling and the PBR map writes that go with them.
]=]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrushTipUtil = require("./BrushTipUtil")
local BrushTips = require(ReplicatedStorage.Shared.Data.BrushTips)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local RegionMaps = require(ReplicatedStorage.Shared.Data.RegionMaps)
local TextureInfo = require("../TextureInfo")

export type ProjectionBrushComputeResult = {
	castedPointOffSet: Vector3,
	castedUp: Vector3,
	projectorCFrame: CFrame,
	projectorBrushSize: Vector3,
	castedCenterPointOffSet: Vector3,
	castedDeltaVecLength: number,
}

export type PBRChannelInfo = {
	circleBrushConfig: BrushConfig,
	lineBrushConfig: BrushConfig,
	editableImage: EditableImage,
}

export type PBRInfo = { [string]: PBRChannelInfo }

export type PixelRect = {
	position: Vector2,
	size: Vector2,
}

-- The top-left editable cell matches CreationConfig.pbrMapCellSize; a body uses that full image,
-- while an accessory packs a grid atlas so its backing image is cell x atlasGridSize per axis.
local function getPbrAtlasCellSize(pbrMap: EditableImage): Vector2
	if
		pbrMap.Size.X == CreationConfig.pbrMapCellSize.X * CreationConfig.atlasGridSize
		and pbrMap.Size.Y == CreationConfig.pbrMapCellSize.Y * CreationConfig.atlasGridSize
	then
		return CreationConfig.pbrMapCellSize
	end
	return Vector2.new(pbrMap.Size.X, pbrMap.Size.Y)
end

-- One byte per PBR texel (0 = no mask, 1 = paint). Region masks are square and their side length
-- must be an integer multiple of each PBR axis.
local function computePbrRegionMask(
	pbrMapSize: Vector2,
	regionBuffer: buffer,
	regionColor: RegionMaps.ColorUInt8
): buffer
	local regionR255 = regionColor.r
	local regionG255 = regionColor.g
	local regionB255 = regionColor.b

	local pbrWidth = pbrMapSize.X
	local pbrHeight = pbrMapSize.Y
	local pixelCount = pbrWidth * pbrHeight
	local mask = buffer.create(pixelCount)

	local regionTexelCount = buffer.len(regionBuffer) / 4
	local regionSideLength = math.sqrt(regionTexelCount)
	local regionSideRounded = math.floor(regionSideLength + 0.5)

	local stepX = regionSideRounded // pbrWidth
	local stepY = regionSideRounded // pbrHeight
	local flatMaskIndex = 0
	for pbrY = 0, pbrHeight - 1 do
		for pbrX = 0, pbrWidth - 1 do
			local regionPixelX = pbrX * stepX
			local regionPixelY = pbrY * stepY
			local regionByteOffset = (regionPixelY * regionSideRounded + regionPixelX) * 4
			local matched = buffer.readu8(regionBuffer, regionByteOffset) == regionR255
				and buffer.readu8(regionBuffer, regionByteOffset + 1) == regionG255
				and buffer.readu8(regionBuffer, regionByteOffset + 2) == regionB255
			buffer.writeu8(mask, flatMaskIndex, if matched then 1 else 0)
			flatMaskIndex += 1
		end
	end

	return mask
end

local function applyMaskToPbrReadBuffer(
	rgbaBuffer: buffer,
	mask1bpp: buffer,
	pixelCount: number,
	colorR255: number,
	colorG255: number,
	colorB255: number
)
	for texelIndex = 0, pixelCount - 1 do
		if buffer.readu8(mask1bpp, texelIndex) ~= 0 then
			local rgbaByteOffset = texelIndex * 4
			buffer.writeu8(rgbaBuffer, rgbaByteOffset, colorR255)
			buffer.writeu8(rgbaBuffer, rgbaByteOffset + 1, colorG255)
			buffer.writeu8(rgbaBuffer, rgbaByteOffset + 2, colorB255)
		end
	end
end

local function getMetalAndRoughColor(isReflective: boolean?): (Color3, Color3)
	if isReflective then
		return CreationConfig.pbrReflectiveMetalColor, CreationConfig.pbrReflectiveRoughColor
	end
	return CreationConfig.pbrDefaultMetalColor, CreationConfig.pbrDefaultRoughColor
end

--[=[
	@within TextureUtils
	@param editableImage EditableImage -- the image to wipe

	Overwrites the whole image with fully transparent black.
]=]
local function clear(editableImage: EditableImage)
	editableImage:DrawRectangle(Vector2.new(), editableImage.Size, Color3.new(), 1.0, Enum.ImageCombineType.Overwrite)
end

--[=[
	@within TextureUtils
	@param oldPosition Vector2 -- where the last stamp landed
	@param newPosition Vector2 -- where this stamp lands
	@param brushSize number -- brush radius in pixels (`DrawCircle` takes a radius)
	@param brushColor Color3 -- brush color
	@param brushTransparency number -- 0 opaque to 1 invisible
	@param editableImage EditableImage -- the layer to stamp onto

	Stamps circles along the segment so a fast drag still paints a continuous stroke.
]=]
local function drawCircleBetweenPoints(
	oldPosition: Vector2,
	newPosition: Vector2,
	brushSize: number,
	brushColor: Color3,
	brushTransparency: number,
	editableImage: EditableImage
)
	local circleRadius = brushSize / 2
	local distBetween = (oldPosition - newPosition).Magnitude

	if distBetween <= 0 then
		editableImage:DrawCircle(newPosition, brushSize, brushColor, brushTransparency, Enum.ImageCombineType.Overwrite)
	end

	for i = 1, distBetween, math.max(math.floor(circleRadius), 1) do
		local interPosition = oldPosition:Lerp(newPosition, i / distBetween)
		interPosition = Vector2.new(math.floor(interPosition.X), math.floor(interPosition.Y))

		editableImage:DrawCircle(
			interPosition,
			brushSize,
			brushColor,
			brushTransparency,
			Enum.ImageCombineType.Overwrite
		)
	end
end

--[=[
	@within TextureUtils
	@param oldPosition Vector2 -- where the last stamp landed
	@param newPosition Vector2 -- where this stamp lands
	@param brushRadius number -- brush radius in pixels, as [TextureUtils.drawCircleBetweenPoints] takes it
	@param tipId string? -- the [BrushTips] tip, or nil for the default
	@param stamp EditableImage -- the tinted tip from [TextureUtils.createLinearStamp]
	@param editableImage EditableImage -- the layer to stamp onto

	Stamps the tip along the segment at the tip's spacing, at sub-pixel positions with filtering, so
	the stroke's edges stay smooth. Blends over the layer, so it paints but never erases.
]=]
local function stampBetweenPoints(
	oldPosition: Vector2,
	newPosition: Vector2,
	brushRadius: number,
	tipId: string?,
	stamp: EditableImage,
	editableImage: EditableImage
)
	local tip = BrushTipUtil.getTip(tipId)
	local diameter = brushRadius * 2
	local scale = Vector2.one * (diameter / stamp.Size.X)
	local spacing = math.max(diameter * tip.spacing, 1)
	local distance = (newPosition - oldPosition).Magnitude
	local steps = math.ceil(distance / spacing)

	local function stampAt(position: Vector2)
		editableImage:DrawImageTransformed(position, scale, 0, stamp, {
			CombineType = Enum.ImageCombineType.BlendSourceOver,
		})
	end

	if steps == 0 then
		stampAt(newPosition)
		return
	end

	for step = 1, steps do
		stampAt(oldPosition:Lerp(newPosition, step / steps))
	end
end

--[=[
	@within TextureUtils
	@param brushRadius number -- brush radius in pixels
	@param brushColor Color3 -- brush color
	@param tipId string? -- the [BrushTips] tip, or nil for the default
	@return EditableImage -- the tip rasterized at the brush's own size, for [TextureUtils.stampBetweenPoints]; caller destroys it
]=]
local function createLinearStamp(brushRadius: number, brushColor: Color3, tipId: string?): EditableImage
	local stamp =
		BrushTipUtil.createStamp(BrushTipUtil.getTip(tipId), math.max(math.ceil(brushRadius * 2), 2), brushColor, false)

	return assert(stamp, CreationStrings.failedToCreateImage)
end

--[=[
	@within TextureUtils
	@param colorA Color3 -- color of the top-left and bottom-right squares
	@param colorB Color3 -- color of the other two squares
	@return EditableImage? -- a 2x2 checker to tile with `ScaleType.Tile`, or nil when no image memory is left
]=]
local function createCheckerImage(colorA: Color3, colorB: Color3): EditableImage?
	local ok, image = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(2, 2) })
	end)
	if not ok or not image then
		return nil
	end

	local pixels = buffer.create(16)
	for index, color in { colorA, colorB, colorB, colorA } do
		local offset = (index - 1) * 4
		buffer.writeu8(pixels, offset, math.round(color.R * 255))
		buffer.writeu8(pixels, offset + 1, math.round(color.G * 255))
		buffer.writeu8(pixels, offset + 2, math.round(color.B * 255))
		buffer.writeu8(pixels, offset + 3, 255)
	end
	image:WritePixelsBuffer(Vector2.zero, image.Size, pixels)

	return image
end

--[=[
	@within TextureUtils
	@param positions { Vector2 } -- the stroke's sample positions
	@param radius number -- how far a stamp reaches past its sample position
	@param imageSize Vector2 -- the image the stroke is drawn on
	@return Vector2 -- top-left of the rect, clamped to the image
	@return Vector2 -- size of the rect, zero when nothing lands on the image

	Bounds the pixels a stroke can touch so reads, writes and stencils can skip the rest.
]=]
local function getStrokeRect(positions: { Vector2 }, radius: number, imageSize: Vector2): (Vector2, Vector2)
	local reach = math.ceil(radius) + 1
	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge

	for _, position in positions do
		minX = math.min(minX, position.X)
		minY = math.min(minY, position.Y)
		maxX = math.max(maxX, position.X)
		maxY = math.max(maxY, position.Y)
	end

	local left = math.clamp(math.floor(minX) - reach, 0, imageSize.X)
	local top = math.clamp(math.floor(minY) - reach, 0, imageSize.Y)
	local right = math.clamp(math.ceil(maxX) + reach, 0, imageSize.X)
	local bottom = math.clamp(math.ceil(maxY) + reach, 0, imageSize.Y)

	return Vector2.new(left, top), Vector2.new(math.max(right - left, 0), math.max(bottom - top, 0))
end

--[=[
	@within TextureUtils
	@param currentRegion TextureInfo.Region? -- the region to keep, or nil to keep everything
	@param previousBuffer buffer -- pixels as they were before the edit, covering the same rect
	@param targetTexture EditableImage -- the layer that was just drawn on
	@param rectPosition Vector2? -- top-left of the edited rect, defaults to the image origin
	@param rectSize Vector2? -- size of the edited rect, defaults to the whole image

	Rolls back every pixel the edit touched outside the region's mask color. Target pixels beyond
	the mask's own size (other kitbash atlas cells) are always rolled back.
]=]
local function performRegionStencil(
	currentRegion: TextureInfo.Region?,
	previousBuffer: buffer,
	targetTexture: EditableImage,
	rectPosition: Vector2?,
	rectSize: Vector2?
)
	if
		currentRegion == nil
		or currentRegion.regionBuffer == nil
		or currentRegion.regionColor == nil
		or currentRegion.regionSize == nil
		or previousBuffer == nil
		or targetTexture == nil
	then
		return
	end

	local origin = rectPosition or Vector2.zero
	local size = rectSize or targetTexture.Size
	local currentBuffer = targetTexture:ReadPixelsBuffer(origin, size)

	local regionBuffer = currentRegion.regionBuffer
	local regionWidth = currentRegion.regionSize.X
	local regionHeight = currentRegion.regionSize.Y
	local regionR255 = currentRegion.regionColor.r
	local regionG255 = currentRegion.regionColor.g
	local regionB255 = currentRegion.regionColor.b

	local rectWidth = size.X
	local originX = origin.X
	local originY = origin.Y

	for y = 0, size.Y - 1 do
		local regionY = originY + y
		if regionY >= regionHeight then
			break
		end

		for x = 0, rectWidth - 1 do
			local regionX = originX + x
			if regionX >= regionWidth then
				break
			end

			local regionIndex = (regionY * regionWidth + regionX) * 4
			if
				buffer.readu8(regionBuffer, regionIndex) == regionR255
				and buffer.readu8(regionBuffer, regionIndex + 1) == regionG255
				and buffer.readu8(regionBuffer, regionIndex + 2) == regionB255
			then
				local i = (y * rectWidth + x) * 4
				buffer.writeu32(previousBuffer, i, buffer.readu32(currentBuffer, i))
			end
		end
	end

	targetTexture:WritePixelsBuffer(origin, size, previousBuffer)
end

--[=[
	@within TextureUtils
	@param region TextureInfo.Region -- the region whose mask to sample
	@param pixel Vector2 -- texel on the region's layer
	@return boolean -- true when the mask carries the region's color at that texel
]=]
local function regionContainsPixel(region: TextureInfo.Region, pixel: Vector2): boolean
	local regionBuffer = region.regionBuffer
	local regionColor = region.regionColor
	local regionSize = region.regionSize
	if regionBuffer == nil or regionColor == nil or regionSize == nil then
		return false
	end

	local regionWidth = regionSize.X
	local regionHeight = regionSize.Y
	local x = math.floor(pixel.X)
	local y = math.floor(pixel.Y)
	if x < 0 or y < 0 or x >= regionWidth or y >= regionHeight then
		return false
	end

	local index = (y * regionWidth + x) * 4

	return buffer.readu8(regionBuffer, index) == regionColor.r
		and buffer.readu8(regionBuffer, index + 1) == regionColor.g
		and buffer.readu8(regionBuffer, index + 2) == regionColor.b
end

--[=[
	@within TextureUtils
	@param editableImage EditableImage -- the image to fade
	@param targetAlpha number -- multiplier applied to every pixel's alpha
]=]
local function applyAlpha(editableImage: EditableImage, targetAlpha: number)
	if targetAlpha >= 1 then
		return
	end

	local size = editableImage.Size

	local eiBuffer = editableImage:ReadPixelsBuffer(Vector2.zero, size)

	for i = 0, buffer.len(eiBuffer) - 1, 4 do
		local alpha = buffer.readu8(eiBuffer, i + 3)
		buffer.writeu8(eiBuffer, i + 3, alpha * targetAlpha)
	end

	editableImage:WritePixelsBuffer(Vector2.zero, size, eiBuffer)
end

--[=[
	@within TextureUtils
	@param mask buffer -- RGBA pixels of a low-res image the same edit was drawn into
	@param maskSize Vector2 -- width and height of the mask in pixels
	@param imageSize Vector2 -- size of the full-res image the mask stands in for
	@return { PixelRect } -- full-res rects covering every marked mask pixel, grown by one mask pixel

	Turns a coarse coverage mask into the full-res regions an edit touched. The one-pixel margin
	covers edges the coarse raster missed.
]=]
local function getMaskDirtyRects(mask: buffer, maskSize: Vector2, imageSize: Vector2): { PixelRect }
	local columns, rows = maskSize.X, maskSize.Y
	local dirty: { [number]: boolean } = {}
	local anyDirty = false

	for y = 0, rows - 1 do
		for x = 0, columns - 1 do
			if buffer.readu8(mask, (y * columns + x) * 4 + 3) > 0 then
				anyDirty = true
				for tileY = math.max(y - 1, 0), math.min(y + 1, rows - 1) do
					for tileX = math.max(x - 1, 0), math.min(x + 1, columns - 1) do
						dirty[tileY * columns + tileX] = true
					end
				end
			end
		end
	end

	local rects = {}
	if not anyDirty then
		return rects
	end

	local tileRects = {}
	local openRects = {}
	for y = 0, rows - 1 do
		local nextOpenRects = {}
		local x = 0
		while x < columns do
			if not dirty[y * columns + x] then
				x += 1
				continue
			end

			local startX = x
			while x < columns and dirty[y * columns + x] do
				x += 1
			end

			local key = startX * (columns + 1) + x
			local tileRect = openRects[key]
			if tileRect then
				tileRect.endY = y + 1
			else
				tileRect = { startX = startX, endX = x, startY = y, endY = y + 1 }
				table.insert(tileRects, tileRect)
			end
			nextOpenRects[key] = tileRect
		end
		openRects = nextOpenRects
	end

	local scaleX = imageSize.X / columns
	local scaleY = imageSize.Y / rows
	for _, tileRect in tileRects do
		local left = math.floor(tileRect.startX * scaleX)
		local top = math.floor(tileRect.startY * scaleY)
		local right = math.min(math.ceil(tileRect.endX * scaleX), imageSize.X)
		local bottom = math.min(math.ceil(tileRect.endY * scaleY), imageSize.Y)
		table.insert(rects, { position = Vector2.new(left, top), size = Vector2.new(right - left, bottom - top) })
	end

	return rects
end

--[=[
	@within TextureUtils
	@param dst buffer -- the destination RGBA buffer, mutated in place
	@param dstWidth number -- width of the destination image in pixels
	@param src buffer -- the source RGBA buffer to tint and composite
	@param srcSize Vector2 -- width and height of the source in pixels
	@param pos Vector2 -- top-left position in the destination to composite at
	@param color Color3 -- the tint multiplied into the source's rgb

	Multiplies `src` by `color` and alpha-composites it over `dst`, preserving the source's own
	alpha silhouette. A per-channel 0-255 lookup table does the tint so the inner loop stays cheap.
]=]
local function blitTintedAlphaOver(
	dst: buffer,
	dstWidth: number,
	src: buffer,
	srcSize: Vector2,
	pos: Vector2,
	color: Color3
)
	local posX, posY = pos.X, pos.Y
	local srcWidth, srcHeight = srcSize.X, srcSize.Y

	local tintR = (color.R * 255 + 0.5) // 1
	local tintG = (color.G * 255 + 0.5) // 1
	local tintB = (color.B * 255 + 0.5) // 1

	local lutR, lutG, lutB = table.create(256), table.create(256), table.create(256)
	for value = 0, 255 do
		lutR[value] = (value * tintR) // 255
		lutG[value] = (value * tintG) // 255
		lutB[value] = (value * tintB) // 255
	end

	for y = 0, srcHeight - 1 do
		local dstRow = ((posY + y) * dstWidth + posX) * 4
		local srcRow = (y * srcWidth) * 4

		for x = 0, srcWidth - 1 do
			local si = srcRow + x * 4
			local sourceAlpha = buffer.readu8(src, si + 3)

			if sourceAlpha == 0 then
				continue
			end

			local di = dstRow + x * 4
			local tintedR = lutR[buffer.readu8(src, si)]
			local tintedG = lutG[buffer.readu8(src, si + 1)]
			local tintedB = lutB[buffer.readu8(src, si + 2)]

			if sourceAlpha == 255 then
				buffer.writeu8(dst, di, tintedR)
				buffer.writeu8(dst, di + 1, tintedG)
				buffer.writeu8(dst, di + 2, tintedB)
				buffer.writeu8(dst, di + 3, 255)
				continue
			end

			local inverseAlpha = 255 - sourceAlpha
			local destR = buffer.readu8(dst, di)
			local destG = buffer.readu8(dst, di + 1)
			local destB = buffer.readu8(dst, di + 2)
			local destA = buffer.readu8(dst, di + 3)

			buffer.writeu8(dst, di, (tintedR * sourceAlpha + destR * inverseAlpha) // 255)
			buffer.writeu8(dst, di + 1, (tintedG * sourceAlpha + destG * inverseAlpha) // 255)
			buffer.writeu8(dst, di + 2, (tintedB * sourceAlpha + destB * inverseAlpha) // 255)
			buffer.writeu8(dst, di + 3, sourceAlpha + (destA * inverseAlpha) // 255)
		end
	end
end

--[=[
	@within TextureUtils
	@param modelInfo ModelInfo -- the model being edited
	@param textureInfo TextureInfo.TextureInfo -- that model's texture set
	@param meshPartNames { string } -- the parts to collect maps for
	@return { [EditableImage]: string } -- each distinct roughness map, keyed to one part that uses it
]=]
local function getRoughnessMaps(modelInfo, textureInfo: TextureInfo.TextureInfo, meshPartNames: { string })
	local uniqueEditableImages = {}

	for _, meshPartName in pairs(meshPartNames) do
		local meshPart = modelInfo:getMeshPartByName(meshPartName)
		local roughnessEI = textureInfo:getRoughnessMap(meshPart)

		uniqueEditableImages[roughnessEI] = meshPartName
	end

	return uniqueEditableImages
end

--[=[
	@within TextureUtils
	@param modelInfo ModelInfo -- the model being edited
	@param textureInfo TextureInfo.TextureInfo -- that model's texture set
	@param meshPartNames { string } -- the parts to collect maps for
	@return { [EditableImage]: string } -- each distinct metalness map, keyed to one part that uses it
]=]
local function getMetalnessMaps(modelInfo, textureInfo: TextureInfo.TextureInfo, meshPartNames: { string })
	local uniqueEditableImages = {}

	for _, meshPartName in pairs(meshPartNames) do
		local meshPart = modelInfo:getMeshPartByName(meshPartName)
		local metalnessEI = textureInfo:getMetalnessMap(meshPart)

		uniqueEditableImages[metalnessEI] = meshPartName
	end

	return uniqueEditableImages
end

--[=[
	@within TextureUtils
	@param pbrMap EditableImage -- the map to recolor
	@param region TextureInfo.Region -- the region whose mask selects the texels
	@param color Color3 -- the color to write
	@return buffer -- the map's pixels with the region recolored, ready to write back
]=]
local function getBufferFromPBRRegionRecolor(pbrMap: EditableImage, region: TextureInfo.Region, color: Color3): buffer
	local pbrMapSize = getPbrAtlasCellSize(pbrMap)
	local mask = computePbrRegionMask(pbrMapSize, region.regionBuffer :: buffer, region.regionColor :: any)
	local currentPixelsBuffer = pbrMap:ReadPixelsBuffer(Vector2.zero, pbrMapSize)

	local colorR255 = color.R * 255
	local colorG255 = color.G * 255
	local colorB255 = color.B * 255

	applyMaskToPbrReadBuffer(currentPixelsBuffer, mask, pbrMapSize.X * pbrMapSize.Y, colorR255, colorG255, colorB255)

	return currentPixelsBuffer
end

--[=[
	@within TextureUtils
	@param textureInfo TextureInfo.TextureInfo -- the model's texture set
	@param meshPart MeshPart -- the part whose maps to rewrite
	@param isReflective boolean? -- true for the shiny metal preset, false for the matte one

	Floods the part's whole metalness and roughness maps with the preset colors.
]=]
local function applyPBRMaps(textureInfo: TextureInfo.TextureInfo, meshPart: MeshPart, isReflective: boolean?)
	local metalnessEI = textureInfo:getMetalnessMap(meshPart)
	local roughnessEI = textureInfo:getRoughnessMap(meshPart)

	local metalColor, roughnessColor = getMetalAndRoughColor(isReflective)

	metalnessEI:DrawRectangle(Vector2.new(0, 0), metalnessEI.Size, metalColor, 0, Enum.ImageCombineType.Overwrite)

	roughnessEI:DrawRectangle(Vector2.new(0, 0), roughnessEI.Size, roughnessColor, 0, Enum.ImageCombineType.Overwrite)
end

--[=[
	@within TextureUtils
	@param modelInfo ModelInfo -- the model being edited
	@param textureInfo TextureInfo.TextureInfo -- that model's texture set
	@param region TextureInfo.Region -- the region to write
	@param isReflective boolean? -- true for the shiny metal preset, false for the matte one

	Regions without a mask fall back to rewriting each covered part's maps in full.
]=]
local function applyPBRToRegion(
	modelInfo,
	textureInfo: TextureInfo.TextureInfo,
	region: TextureInfo.Region,
	isReflective: boolean?
)
	if not region.regionBuffer then
		for _, meshPartName in ipairs(region.meshPartNames) do
			local meshPart = modelInfo:getMeshPartByName(meshPartName)
			if meshPart then
				applyPBRMaps(textureInfo, meshPart, isReflective)
			end
		end
		return
	end

	local metalColor, roughnessColor = getMetalAndRoughColor(isReflective)

	local roughnessMaps = getRoughnessMaps(modelInfo, textureInfo, region.meshPartNames)
	local metalnessMaps = getMetalnessMaps(modelInfo, textureInfo, region.meshPartNames)

	local sampleEditableImage: EditableImage? = nil
	for roughnessEditable, _ in roughnessMaps do
		sampleEditableImage = roughnessEditable
		break
	end
	if not sampleEditableImage then
		for metalnessEditable, _ in metalnessMaps do
			sampleEditableImage = metalnessEditable
			break
		end
	end
	if not sampleEditableImage then
		return
	end

	local pbrCellSize = getPbrAtlasCellSize(sampleEditableImage)
	local mask = computePbrRegionMask(pbrCellSize, region.regionBuffer, region.regionColor :: any)
	local texelCount = pbrCellSize.X * pbrCellSize.Y

	local roughnessR255 = roughnessColor.R * 255
	local roughnessG255 = roughnessColor.G * 255
	local roughnessB255 = roughnessColor.B * 255
	local metalnessR255 = metalColor.R * 255
	local metalnessG255 = metalColor.G * 255
	local metalnessB255 = metalColor.B * 255

	for roughnessEditable, _ in roughnessMaps do
		local atlasWriteSize = getPbrAtlasCellSize(roughnessEditable)
		local roughnessBuffer = roughnessEditable:ReadPixelsBuffer(Vector2.zero, atlasWriteSize)
		applyMaskToPbrReadBuffer(roughnessBuffer, mask, texelCount, roughnessR255, roughnessG255, roughnessB255)
		roughnessEditable:WritePixelsBuffer(Vector2.zero, atlasWriteSize, roughnessBuffer)
	end

	for metalnessEditable, _ in metalnessMaps do
		local atlasWriteSize = getPbrAtlasCellSize(metalnessEditable)
		local metalnessBuffer = metalnessEditable:ReadPixelsBuffer(Vector2.zero, atlasWriteSize)
		applyMaskToPbrReadBuffer(metalnessBuffer, mask, texelCount, metalnessR255, metalnessG255, metalnessB255)
		metalnessEditable:WritePixelsBuffer(Vector2.zero, atlasWriteSize, metalnessBuffer)
	end
end

--[=[
	@within TextureUtils
	@param textureInfo TextureInfo.TextureInfo -- the model's texture set
	@param meshPart MeshPart -- the part to reset

	Puts the part's metalness and roughness maps back to the matte preset.
]=]
local function clearPBR(textureInfo: TextureInfo.TextureInfo, meshPart: MeshPart)
	applyPBRMaps(textureInfo, meshPart, false)
end

--[=[
	@within TextureUtils
	@param currentPixelsBuffer buffer -- the target layer's pixels, mutated in place
	@param currentRegion TextureInfo.Region -- the region whose mask selects the pixels
	@param color Color3 -- the color to write
	@param targetTexture EditableImage -- the layer to write back to
	@param textureSize Vector2 -- the write extent
	@param fillAlphaByte number -- alpha written to every recolored pixel, 0 to 255
]=]
local function performRegionColor(
	currentPixelsBuffer: buffer,
	currentRegion: TextureInfo.Region,
	color: Color3,
	targetTexture: EditableImage,
	textureSize: Vector2,
	fillAlphaByte: number
)
	local regionPixelsBuffer = currentRegion.regionBuffer

	local regionColor = currentRegion.regionColor :: RegionMaps.ColorUInt8
	local regionR255 = regionColor.r
	local regionG255 = regionColor.g
	local regionB255 = regionColor.b

	local colorR255 = color.R * 255
	local colorG255 = color.G * 255
	local colorB255 = color.B * 255

	for i = 0, buffer.len(currentPixelsBuffer) - 1, 4 do
		if
			buffer.readu8(regionPixelsBuffer, i) == regionR255
			and buffer.readu8(regionPixelsBuffer, i + 1) == regionG255
			and buffer.readu8(regionPixelsBuffer, i + 2) == regionB255
		then
			buffer.writeu8(currentPixelsBuffer, i, colorR255)
			buffer.writeu8(currentPixelsBuffer, i + 1, colorG255)
			buffer.writeu8(currentPixelsBuffer, i + 2, colorB255)
			buffer.writeu8(currentPixelsBuffer, i + 3, fillAlphaByte)
		end
	end

	targetTexture:WritePixelsBuffer(Vector2.zero, textureSize, currentPixelsBuffer)
end

--[=[
	@within TextureUtils
	@param projectionDirection Vector3 -- world-space direction the brush projects along
	@param currMeshPart MeshPart -- the part being painted
	@param currEditableMesh EditableMesh -- that part's editable mesh
	@param circlePosition Vector3 -- world-space centre of the round cap
	@param linePosition Vector3 -- world-space centre of the connecting bar
	@param brushSize number -- brush width in studs
	@param lineLength number -- length of the connecting bar, 0 for a single stamp
	@param lineUpVec Vector3 -- world-space up vector of the connecting bar
	@param circleBrushConfig BrushConfig -- decal config for the round cap
	@param lineBrushConfig BrushConfig -- decal config for the connecting bar
	@param targetEditableImage EditableImage -- the layer to project onto
	@param pbrInfo PBRInfo -- per-channel PBR maps and configs to project alongside
]=]
local function drawProjectionBrush(
	projectionDirection: Vector3,
	currMeshPart: MeshPart,
	currEditableMesh: EditableMesh,
	circlePosition: Vector3,
	linePosition: Vector3,
	brushSize: number,
	lineLength: number,
	lineUpVec: Vector3,
	circleBrushConfig: BrushConfig,
	lineBrushConfig: BrushConfig,
	targetEditableImage: EditableImage,
	pbrInfo: PBRInfo
)
	local currentDirection = currMeshPart.CFrame:VectorToObjectSpace(projectionDirection)

	local circleBrushProjection: ProjectionParams = {
		Direction = currentDirection,
		Position = currMeshPart.CFrame:PointToObjectSpace(circlePosition),
		Size = Vector3.new(brushSize, brushSize, 100),
		Up = currMeshPart.CFrame:VectorToObjectSpace(Vector3.new(0, 1, 0)),
	}

	targetEditableImage:DrawImageProjected(currEditableMesh, circleBrushProjection, circleBrushConfig)

	for _, channelInfo in pairs(pbrInfo) do
		if channelInfo and channelInfo.editableImage then
			channelInfo.editableImage:DrawImageProjected(
				currEditableMesh,
				circleBrushProjection,
				channelInfo.circleBrushConfig
			)
		end
	end

	local lineExist = lineLength > 0
	if lineExist then
		local lineBrushProjection: ProjectionParams = {
			Direction = currentDirection,
			Position = currMeshPart.CFrame:PointToObjectSpace(linePosition),
			Size = Vector3.new(lineLength, brushSize, 100),
			Up = currMeshPart.CFrame:VectorToObjectSpace(lineUpVec),
		}

		targetEditableImage:DrawImageProjected(currEditableMesh, lineBrushProjection, lineBrushConfig)

		for _, channelInfo in pairs(pbrInfo) do
			if channelInfo and channelInfo.editableImage then
				channelInfo.editableImage:DrawImageProjected(
					currEditableMesh,
					lineBrushProjection,
					channelInfo.lineBrushConfig
				)
			end
		end
	end
end

--[=[
	@within TextureUtils
	@param penColor Color3 -- the color both decals are filled with
	@param colorBlendType Enum.ImageCombineType -- how the decal color combines with the layer
	@param alphaBlendType Enum.ImageAlphaType -- how the decal alpha combines with the layer; anything but Default erases
	@param tipId string? -- the [BrushTips] tip to stamp, or nil for the default
	@return EditableImage -- the round cap decal, caller destroys it
	@return EditableImage -- the connecting bar decal, caller destroys it
	@return BrushConfig -- config wrapping the round cap decal
	@return BrushConfig -- config wrapping the connecting bar decal

	Projection samples its decal without filtering, so the cap is rasterized at the tip's full
	stamp resolution with a soft edge rather than scaled up from a small hard circle.
]=]
local function createAndSetupProjectionBrushTexturesAndConfigs(
	penColor: Color3,
	colorBlendType: Enum.ImageCombineType,
	alphaBlendType: Enum.ImageAlphaType,
	tipId: string?
): (EditableImage, EditableImage, BrushConfig, BrushConfig)
	local tip = BrushTipUtil.getTip(tipId)
	local isErasing = alphaBlendType ~= Enum.ImageAlphaType.Default

	local circleTexture = BrushTipUtil.createStamp(tip, BrushTips.stampResolution, penColor, isErasing)
	local lineTexture = BrushTipUtil.createSegmentStamp(tip, 4, BrushTips.stampResolution, penColor, isErasing)
	assert(circleTexture and lineTexture, CreationStrings.failedToCreateImage)

	local circleBrushConfig: BrushConfig = {
		Decal = circleTexture,
		ColorBlendType = colorBlendType,
		AlphaBlendType = alphaBlendType,
		BlendIntensity = 1,
		FadeAngle = 180.0,
	}

	local lineBrushConfig: BrushConfig = {
		Decal = lineTexture,
		ColorBlendType = colorBlendType,
		AlphaBlendType = alphaBlendType,
		BlendIntensity = 1,
		FadeAngle = 180.0,
	}

	return circleTexture, lineTexture, circleBrushConfig, lineBrushConfig
end

--[=[
	@within TextureUtils
	@param prevPoint Vector3 -- world-space position of the previous sample
	@param currPoint Vector3 -- world-space position of this sample
	@param cameraCFrame CFrame -- the camera the stroke is projected from
	@param brushSize number -- brush width in studs
	@return ProjectionBrushComputeResult -- the projector placement for this stroke segment
]=]
local function generateProjectionBrushPoints(
	prevPoint: Vector3,
	currPoint: Vector3,
	cameraCFrame: CFrame,
	brushSize: number
): ProjectionBrushComputeResult
	local castedDelta = currPoint + prevPoint
	local castedCenterPoint = castedDelta * 0.5

	local cameraDirection = cameraCFrame.LookVector

	local currPointOffSet = currPoint - cameraDirection
	local castedCenterPointOffSet = castedCenterPoint - cameraDirection

	local castedDeltaVec = currPoint - prevPoint
	local castedDeltaVecLength = castedDeltaVec.Magnitude
	local castedUp = castedDeltaVec:Cross(cameraDirection).Unit

	local projectorCFrame = CFrame.new(castedCenterPointOffSet) * cameraCFrame.Rotation
	local projectorBrushSize = Vector3.new(castedDeltaVecLength + brushSize, brushSize, 100)

	local projectionBrushComputeResult: ProjectionBrushComputeResult = {
		castedPointOffSet = currPointOffSet,
		castedUp = castedUp,
		projectorCFrame = projectorCFrame,
		projectorBrushSize = projectorBrushSize,
		castedCenterPointOffSet = castedCenterPointOffSet,
		castedDeltaVecLength = castedDeltaVecLength,
	}

	return projectionBrushComputeResult
end

--[=[
	@within TextureUtils
	@param isErasing boolean -- true when the stroke removes paint rather than adding it
	@param isReflectiveMode boolean? -- true for the shiny metal preset
	@param roughnessMap EditableImage -- the part's roughness map
	@param metalnessMap EditableImage -- the part's metalness map
	@param normalMap EditableImage -- the part's normal map
	@param tipId string? -- the [BrushTips] tip the color stroke uses, so the PBR stamps match it
	@return PBRInfo -- per-channel decal configs to project alongside the color stroke
	@return { EditableImage } -- the decals backing those configs, caller destroys them

	An erasing or reflective stroke leaves the normal map alone.
]=]
local function generatePBRInfo(
	isErasing: boolean,
	isReflectiveMode: boolean?,
	roughnessMap: EditableImage,
	metalnessMap: EditableImage,
	normalMap: EditableImage,
	tipId: string?
): (PBRInfo, { EditableImage })
	local pbrInfo = {}
	local pbrBrushTextures = {}
	local pbrChannels = {}
	if not isErasing and isReflectiveMode then
		pbrChannels = {
			Metalness = {
				defaultColor = CreationConfig.pbrReflectiveMetalColor,
				editableImage = metalnessMap,
			},
			Roughness = {
				defaultColor = CreationConfig.pbrReflectiveRoughColor,
				editableImage = roughnessMap,
			},
		}
	else
		pbrChannels = {
			Metalness = {
				defaultColor = CreationConfig.pbrDefaultMetalColor,
				editableImage = metalnessMap,
			},
			Roughness = {
				defaultColor = CreationConfig.pbrDefaultRoughColor,
				editableImage = roughnessMap,
			},
			Normal = {
				defaultColor = CreationConfig.pbrDefaultNormalColor,
				editableImage = normalMap,
			},
		}
	end

	for channelName, channelData in pairs(pbrChannels) do
		local circleBrush, lineBrush, circleConfig, lineConfig = createAndSetupProjectionBrushTexturesAndConfigs(
			channelData.defaultColor,
			Enum.ImageCombineType.BlendSourceOver,
			Enum.ImageAlphaType.Default,
			tipId
		)

		pbrInfo[channelName] = {
			circleBrushConfig = circleConfig,
			lineBrushConfig = lineConfig,
			editableImage = channelData.editableImage,
		}

		table.insert(pbrBrushTextures, circleBrush)
		table.insert(pbrBrushTextures, lineBrush)
	end

	return pbrInfo, pbrBrushTextures
end

--[=[
	@within TextureUtils
	@param colorMapSize Vector2 -- size of the layer being recolored
	@param regionPixelsBuffer buffer -- the region mask, larger than the layer
	@param currentPixelsBuffer buffer -- the layer's pixels, mutated in place
	@param _originalPixelsBuffer buffer -- unused
	@param regionColor RegionMaps.ColorUInt8 -- the mask color that marks this region
	@param actionColor Color3 -- the color to write
	@param fillAlphaByte number -- alpha written to every recolored pixel, 0 to 255

	A layer pixel is recolored when any mask pixel covering it carries the region color.
]=]
-- Roblox's template declared an unused `originalPixelsBuffer` fourth parameter that its only
-- call site never passed, so every argument from there on landed one slot early: `regionColor`
-- received a Color3 and its `.r`/`.g`/`.b` came back as 0-1 floats, which never matched the
-- 0-255 bytes read out of the region mask. The loop below then matched nothing and the whole
-- function burned CPU doing no work. Dropping the unused parameter realigns the existing call.
local function writeBufferForLargerRegionMap(
	colorMapSize: Vector2,
	regionPixelsBuffer: buffer,
	currentPixelsBuffer: buffer,
	regionColor: RegionMaps.ColorUInt8,
	actionColor: Color3,
	fillAlphaByte: number
)
	local regionR255 = regionColor.r
	local regionG255 = regionColor.g
	local regionB255 = regionColor.b

	local colorR255 = actionColor.R * 255
	local colorG255 = actionColor.G * 255
	local colorB255 = actionColor.B * 255

	local currentWidth, currentHeight = colorMapSize.X, colorMapSize.Y
	local regionTotalPixels = buffer.len(regionPixelsBuffer) / 4
	local regionSize = math.sqrt(regionTotalPixels)
	local scaleX = regionSize / currentWidth
	local scaleY = regionSize / currentHeight

	for y = 0, currentHeight - 1 do
		for x = 0, currentWidth - 1 do
			local currentPos = ((y * currentWidth) + x) * 4
			local matchFound = false

			local regionStartX = math.floor(x * scaleX)
			local regionStartY = math.floor(y * scaleY)
			local regionEndX = math.floor((x + 1) * scaleX)
			local regionEndY = math.floor((y + 1) * scaleY)

			for regionY = regionStartY, regionEndY - 1 do
				for regionX = regionStartX, regionEndX - 1 do
					local regionPos = ((regionY * regionSize) + regionX) * 4

					if regionPos >= 0 and regionPos < buffer.len(regionPixelsBuffer) - 3 then
						if
							buffer.readu8(regionPixelsBuffer, regionPos) == regionR255
							and buffer.readu8(regionPixelsBuffer, regionPos + 1) == regionG255
							and buffer.readu8(regionPixelsBuffer, regionPos + 2) == regionB255
						then
							matchFound = true
							break
						end
					end
				end

				if matchFound then
					break
				end
			end
			if matchFound then
				buffer.writeu8(currentPixelsBuffer, currentPos, colorR255)
				buffer.writeu8(currentPixelsBuffer, currentPos + 1, colorG255)
				buffer.writeu8(currentPixelsBuffer, currentPos + 2, colorB255)
				buffer.writeu8(currentPixelsBuffer, currentPos + 3, fillAlphaByte)
			end
		end
	end
end

return {
	clear = clear,
	createCheckerImage = createCheckerImage,
	drawCircleBetweenPoints = drawCircleBetweenPoints,
	stampBetweenPoints = stampBetweenPoints,
	createLinearStamp = createLinearStamp,
	getStrokeRect = getStrokeRect,
	performRegionStencil = performRegionStencil,
	regionContainsPixel = regionContainsPixel,
	applyAlpha = applyAlpha,
	getMaskDirtyRects = getMaskDirtyRects,
	blitTintedAlphaOver = blitTintedAlphaOver,
	getRoughnessMaps = getRoughnessMaps,
	getMetalnessMaps = getMetalnessMaps,
	getBufferFromPBRRegionRecolor = getBufferFromPBRRegionRecolor,
	applyPBRMaps = applyPBRMaps,
	applyPBRToRegion = applyPBRToRegion,
	clearPBR = clearPBR,
	performRegionColor = performRegionColor,
	drawProjectionBrush = drawProjectionBrush,
	createAndSetupProjectionBrushTexturesAndConfigs = createAndSetupProjectionBrushTexturesAndConfigs,
	generateProjectionBrushPoints = generateProjectionBrushPoints,
	generatePBRInfo = generatePBRInfo,
	writeBufferForLargerRegionMap = writeBufferForLargerRegionMap,
}

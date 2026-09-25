--[=[
	@class UVWireframe

	Draws a mesh's UV layout (every triangle edge) onto an EditableImage, so a flat texture can be
	shown with the islands it maps onto. UVs use the top-left / v-down convention, matching
	[UVRegionMask] and the creation color textures.
]=]

-- Blending leaves the fully transparent pixels around each line black, which a filtered
-- (scaled-down) view blends into the line as a dark outline; give them the line color instead.
local function tintTransparentPixels(target: EditableImage, color: Color3)
	local pixels = target:ReadPixelsBuffer(Vector2.zero, target.Size)
	local r, g, b = math.round(color.R * 255), math.round(color.G * 255), math.round(color.B * 255)

	for i = 0, buffer.len(pixels) - 4, 4 do
		if buffer.readu8(pixels, i + 3) == 0 then
			buffer.writeu8(pixels, i, r)
			buffer.writeu8(pixels, i + 1, g)
			buffer.writeu8(pixels, i + 2, b)
		end
	end

	target:WritePixelsBuffer(Vector2.zero, target.Size, pixels)
end

--[=[
	@within UVWireframe
	@param editableMeshes { EditableMesh } -- meshes whose UV edges to draw
	@param target EditableImage -- the image to draw onto; edges reaching past it are skipped
	@param uvToPixel Vector2 -- pixel size of UV space 0-1, which can exceed `target` for an atlas
	@param color Color3 -- line color
	@param transparency number -- line transparency, 0 opaque to 1 hidden
	@param thickness number -- line width in pixels
	@param facesPerYield number? -- yield a frame after this many faces, or never when nil
	@return number -- how many edges were drawn
]=]
local function rasterize(
	editableMeshes: { EditableMesh },
	target: EditableImage,
	uvToPixel: Vector2,
	color: Color3,
	transparency: number,
	thickness: number,
	facesPerYield: number?
): number
	local maxX = target.Size.X
	local maxY = target.Size.Y
	local lastPixel = target.Size - Vector2.one
	local drawnEdges = 0
	local facesSinceYield = 0

	local strokeOffsets = { Vector2.zero }
	local firstOffset = -math.floor((thickness - 1) / 2)
	for step = firstOffset, firstOffset + thickness - 1 do
		if step ~= 0 then
			table.insert(strokeOffsets, Vector2.new(step, 0))
			table.insert(strokeOffsets, Vector2.new(0, step))
		end
	end

	for _, editableMesh in editableMeshes do
		local drawnKeys: { [string]: boolean } = {}
		local uvPixels: { [number]: Vector2 } = {}

		local function getUVPixel(uvId: number): Vector2
			local pixel = uvPixels[uvId]
			if not pixel then
				pixel = editableMesh:GetUV(uvId) * uvToPixel
				uvPixels[uvId] = pixel
			end

			return pixel
		end

		local function drawEdge(uvIdA: number, uvIdB: number)
			local key = if uvIdA < uvIdB then `{uvIdA}:{uvIdB}` else `{uvIdB}:{uvIdA}`
			if drawnKeys[key] then
				return
			end
			drawnKeys[key] = true

			local a = getUVPixel(uvIdA)
			local b = getUVPixel(uvIdB)
			if math.min(a.X, a.Y, b.X, b.Y) < 0 or a.X > maxX or a.Y > maxY or b.X > maxX or b.Y > maxY then
				return
			end

			for _, offset in strokeOffsets do
				target:DrawLine(
					(a + offset):Max(Vector2.zero):Min(lastPixel),
					(b + offset):Max(Vector2.zero):Min(lastPixel),
					color,
					transparency,
					Enum.ImageCombineType.BlendSourceOver
				)
			end
			drawnEdges += 1
		end

		for _, faceId in editableMesh:GetFaces() do
			local faceUVs = editableMesh:GetFaceUVs(faceId)
			if #faceUVs == 3 then
				drawEdge(faceUVs[1], faceUVs[2])
				drawEdge(faceUVs[2], faceUVs[3])
				drawEdge(faceUVs[3], faceUVs[1])
			end

			facesSinceYield += 1
			if facesPerYield and facesSinceYield >= facesPerYield then
				facesSinceYield = 0
				task.wait()
			end
		end
	end

	tintTransparentPixels(target, color)

	return drawnEdges
end

return {
	rasterize = rasterize,
}

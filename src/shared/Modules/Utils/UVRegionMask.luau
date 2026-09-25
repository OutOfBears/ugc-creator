--[=[
	@class UVRegionMask

	Decodes the base64 UV-region blob authored by the Blender exporter (see `tool/` — the
	`UVRG` format) and rasterizes each region's UV triangles into a texture-space mask.

	The mask it builds is a shared RGBA buffer, one flag color per region, matching the shape the
	old flag-colored region-mask *textures* produced -- so it drops straight into
	`TextureUtils.performRegionColor` with no downstream change. UVs use the top-left / v-down
	convention (`row = v * height`), matching the creation color textures.
]=]

local QUANT_MAX = 65535
local MAGIC = "UVRG"
local VERSION = 1

export type ColorUInt8 = {
	r: number,
	g: number,
	b: number,
}

type Triangle = { number } -- { au, av, bu, bv, cu, cv }, UVs in [0, 1]

export type RegionData = {
	name: string,
	triangles: { Triangle },
}

export type BuiltMask = {
	buffer: buffer,
	regionColors: { [string]: ColorUInt8 },
}

-- Distinct, non-zero flag color per region index (0 is reserved for "unpainted"). 24 bits of
-- index space, so collisions are impossible for any realistic region count.
local function flagForIndex(index: number): ColorUInt8
	return {
		r = index % 256,
		g = math.floor(index / 256) % 256,
		b = math.floor(index / 65536) % 256,
	}
end

--[=[
	@within UVRegionMask
	@param bytes buffer -- the raw decoded blob (base64 already stripped)
	@return { RegionData } -- one entry per region, triangles dequantized to [0, 1]
]=]
local function decode(bytes: buffer): { RegionData }
	assert(buffer.readstring(bytes, 0, 4) == MAGIC, "UVRegionMask: bad magic")
	assert(buffer.readu8(bytes, 4) == VERSION, "UVRegionMask: unsupported version")

	local regionCount = buffer.readu16(bytes, 6)
	local offset = 8

	local uvCount = buffer.readu32(bytes, offset)
	offset += 4

	local us = table.create(uvCount)
	local vs = table.create(uvCount)
	for i = 1, uvCount do
		us[i] = buffer.readu16(bytes, offset) / QUANT_MAX
		vs[i] = buffer.readu16(bytes, offset + 2) / QUANT_MAX
		offset += 4
	end

	local regions = table.create(regionCount)
	for _ = 1, regionCount do
		local nameLen = buffer.readu16(bytes, offset)
		offset += 2
		local name = buffer.readstring(bytes, offset, nameLen)
		offset += nameLen

		local triCount = buffer.readu32(bytes, offset)
		offset += 4

		local triangles = table.create(triCount)
		for t = 1, triCount do
			local a = buffer.readu32(bytes, offset) + 1
			local b = buffer.readu32(bytes, offset + 4) + 1
			local c = buffer.readu32(bytes, offset + 8) + 1
			offset += 12
			triangles[t] = { us[a], vs[a], us[b], vs[b], us[c], vs[c] }
		end

		regions[#regions + 1] = { name = name, triangles = triangles }
	end

	return regions
end

local function rasterizeTriangle(mask: buffer, tri: Triangle, width: number, height: number)
	local ax, ay = tri[1] * width, tri[2] * height
	local bx, by = tri[3] * width, tri[4] * height
	local cx, cy = tri[5] * width, tri[6] * height

	local minX = math.max(0, math.floor(math.min(ax, bx, cx)))
	local maxX = math.min(width - 1, math.ceil(math.max(ax, bx, cx)))
	local minY = math.max(0, math.floor(math.min(ay, by, cy)))
	local maxY = math.min(height - 1, math.ceil(math.max(ay, by, cy)))

	for py = minY, maxY do
		local sy = py + 0.5
		for px = minX, maxX do
			local sx = px + 0.5
			local w0 = (bx - ax) * (sy - ay) - (by - ay) * (sx - ax)
			local w1 = (cx - bx) * (sy - by) - (cy - by) * (sx - bx)
			local w2 = (ax - cx) * (sy - cy) - (ay - cy) * (sx - cx)

			if (w0 >= 0 and w1 >= 0 and w2 >= 0) or (w0 <= 0 and w1 <= 0 and w2 <= 0) then
				buffer.writeu8(mask, py * width + px, 1)
			end
		end
	end
end

local function dilate(mask: buffer, width: number, height: number, iterations: number)
	local count = width * height
	for _ = 1, iterations do
		local previous = buffer.create(count)
		buffer.copy(previous, 0, mask, 0, count)

		for y = 0, height - 1 do
			for x = 0, width - 1 do
				local i = y * width + x
				if buffer.readu8(previous, i) == 0 then
					local hit = (x > 0 and buffer.readu8(previous, i - 1) ~= 0)
						or (x < width - 1 and buffer.readu8(previous, i + 1) ~= 0)
						or (y > 0 and buffer.readu8(previous, i - width) ~= 0)
						or (y < height - 1 and buffer.readu8(previous, i + width) ~= 0)
					if hit then
						buffer.writeu8(mask, i, 1)
					end
				end
			end
		end
	end
end

local function stamp(rgba: buffer, mask: buffer, count: number, color: ColorUInt8)
	for i = 0, count - 1 do
		if buffer.readu8(mask, i) ~= 0 then
			local off = i * 4
			buffer.writeu8(rgba, off, color.r)
			buffer.writeu8(rgba, off + 1, color.g)
			buffer.writeu8(rgba, off + 2, color.b)
			buffer.writeu8(rgba, off + 3, 255)
		end
	end
end

--[=[
	@within UVRegionMask
	@param bytes buffer -- the raw decoded blob
	@param width number -- target color-map width in texels
	@param height number -- target color-map height in texels
	@param dilatePixels number? -- seam-closing dilation radius, defaults to 1
	@return BuiltMask -- shared RGBA mask buffer plus each region's flag color

	Rasterizes every region into one shared buffer, each with a unique flag color. Feed
	`buffer` as `region.regionBuffer` and `regionColors[name]` as `region.regionColor`.
]=]
local function build(bytes: buffer, width: number, height: number, dilatePixels: number?): BuiltMask
	local count = width * height
	local rgba = buffer.create(count * 4)
	local mask = buffer.create(count)
	local dilation = if dilatePixels ~= nil then dilatePixels else 1

	local regionColors: { [string]: ColorUInt8 } = {}
	local regions = decode(bytes)

	for index, region in ipairs(regions) do
		buffer.fill(mask, 0, 0, count)
		for _, tri in region.triangles do
			rasterizeTriangle(mask, tri, width, height)
		end
		if dilation > 0 then
			dilate(mask, width, height, dilation)
		end

		local color = flagForIndex(index)
		regionColors[region.name] = color
		stamp(rgba, mask, count, color)
	end

	return { buffer = rgba, regionColors = regionColors }
end

--[=[
	@within UVRegionMask
	@param blob string -- the base64 text produced by the exporter
	@return buffer -- the raw decoded bytes, ready for `decode` / `build`
]=]
local function fromBase64(blob: string): buffer
	local EncodingService = game:GetService("EncodingService")
	return (EncodingService :: any):Base64Decode(buffer.fromstring(blob))
end

return {
	decode = decode,
	build = build,
	fromBase64 = fromBase64,
}

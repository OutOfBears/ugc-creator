local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrushTips = require(ReplicatedStorage.Shared.Data.BrushTips)

local masks: { [string]: buffer } = {}

-- Coverage of a round tip at `distance` from its centre: full inside `radius * hardness`, easing
-- to zero at `radius`. The fade is at least one pixel wide, so a hard tip is still anti-aliased.
local function roundCoverage(distance: number, radius: number, hardness: number): number
	local edgeWidth = math.max(radius * (1 - hardness), 1)
	local t = math.clamp((radius - distance) / edgeWidth, 0, 1)

	return t * t * (3 - 2 * t)
end

local function getMask(tip: BrushTips.BrushTip, size: number): buffer
	local key = `{tip.hardness}:{size}`
	local cached = masks[key]
	if cached then
		return cached
	end

	local mask = buffer.create(size * size)
	local radius = size / 2
	for y = 0, size - 1 do
		local dy = y + 0.5 - radius
		for x = 0, size - 1 do
			local dx = x + 0.5 - radius
			local coverage = roundCoverage(math.sqrt(dx * dx + dy * dy), radius, tip.hardness)
			buffer.writeu8(mask, y * size + x, math.round(coverage * 255))
		end
	end

	masks[key] = mask

	return mask
end

local function writeTinted(image: EditableImage, alphas: buffer, color: Color3, invert: boolean)
	local r = math.round(color.R * 255)
	local g = math.round(color.G * 255)
	local b = math.round(color.B * 255)

	local count = buffer.len(alphas)
	local pixels = buffer.create(count * 4)
	for i = 0, count - 1 do
		local alpha = buffer.readu8(alphas, i)
		local offset = i * 4
		buffer.writeu8(pixels, offset, r)
		buffer.writeu8(pixels, offset + 1, g)
		buffer.writeu8(pixels, offset + 2, b)
		buffer.writeu8(pixels, offset + 3, if invert then 255 - alpha else alpha)
	end

	image:WritePixelsBuffer(Vector2.zero, image.Size, pixels)
end

--[=[
	@class BrushTipUtil

	Rasterizes [BrushTips] into stamp images. The alpha mask for a tip is computed once per size and
	reused, so tinting a stamp for a new color is the only per-stroke cost.
]=]
local BrushTipUtil = {}

--[=[
	@within BrushTipUtil
	@param tipId string? -- a [BrushTips] id; nil or unknown falls back to the default tip
	@return BrushTip -- the resolved tip
]=]
function BrushTipUtil.getTip(tipId: string?): BrushTips.BrushTip
	return (tipId and BrushTips.tips[tipId]) or BrushTips.tips[BrushTips.defaultTipId]
end

--[=[
	@within BrushTipUtil
	@param tip BrushTip -- the tip to rasterize
	@param size number -- width and height in pixels
	@param color Color3 -- color of every pixel
	@param invert boolean -- true for an eraser stamp: transparent in the middle, opaque outside
	@return EditableImage? -- the stamp, or nil when the image budget is full; caller destroys it
]=]
function BrushTipUtil.createStamp(tip: BrushTips.BrushTip, size: number, color: Color3, invert: boolean): EditableImage?
	local image = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
	if not image then
		return nil
	end

	writeTinted(image, getMask(tip, size), color, invert)

	return image
end

--[=[
	@within BrushTipUtil
	@param tip BrushTip -- the tip whose cross-section to use
	@param width number -- pixels along the stroke
	@param size number -- pixels across the stroke
	@param color Color3 -- color of every pixel
	@param invert boolean -- true for an eraser stamp
	@return EditableImage? -- the stamp, or nil when the image budget is full; caller destroys it

	A stamp for the segment joining two round stamps: every column is the tip's cross-section
	through its centre, so the segment's edges fade exactly like the round stamps at its ends.
]=]
function BrushTipUtil.createSegmentStamp(
	tip: BrushTips.BrushTip,
	width: number,
	size: number,
	color: Color3,
	invert: boolean
): EditableImage?
	local image = AssetService:CreateEditableImage({ Size = Vector2.new(width, size) })
	if not image then
		return nil
	end

	local mask = getMask(tip, size)
	local centreRow = math.floor(size / 2)
	local alphas = buffer.create(width * size)
	for y = 0, size - 1 do
		local alpha = buffer.readu8(mask, centreRow * size + y)
		buffer.fill(alphas, y * width, alpha, width)
	end

	writeTinted(image, alphas, color, invert)

	return image
end

return BrushTipUtil

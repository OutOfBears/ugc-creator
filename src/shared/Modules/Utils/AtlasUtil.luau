local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)

--[=[
	@class AtlasUtil

	Maps between a texture atlas's UV-space rects (`CreationConfig.atlasLayouts`) and the pixels and
	UVs of the image they divide.
]=]
local AtlasUtil = {}

--[=[
	@within AtlasUtil
	@param rect AtlasRect -- a rect of the atlas in UV space
	@param imageSize Vector2 -- the size of the atlas image
	@return Vector2 -- the rect's top-left pixel
	@return Vector2 -- the rect's size in pixels

	Edges are floored, so neighbouring rects tile the image with no gap or overlap.
]=]
function AtlasUtil.toPixels(rect: CreationConfig.AtlasRect, imageSize: Vector2): (Vector2, Vector2)
	local minX = math.floor(rect.uOffset * imageSize.X)
	local minY = math.floor(rect.vOffset * imageSize.Y)
	local maxX = math.floor((rect.uOffset + rect.uScale) * imageSize.X)
	local maxY = math.floor((rect.vOffset + rect.vScale) * imageSize.Y)

	return Vector2.new(minX, minY), Vector2.new(maxX - minX, maxY - minY)
end

--[=[
	@within AtlasUtil
	@param uv Vector2 -- a UV over the whole of a texture
	@param rect AtlasRect -- the rect that texture occupies in the atlas
	@return Vector2 -- the same point in the atlas's UV space
]=]
function AtlasUtil.remapUV(uv: Vector2, rect: CreationConfig.AtlasRect): Vector2
	return Vector2.new(rect.uOffset + uv.X * rect.uScale, rect.vOffset + uv.Y * rect.vScale)
end

return AtlasUtil

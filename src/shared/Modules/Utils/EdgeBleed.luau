--[=[
	@class EdgeBleed

	Keeps painted edges clean when an image with transparent areas is shown scaled down. Fully
	transparent pixels are stored black, and filtering blends that black into neighbouring paint as
	a dark outline; bleeding the paint's color into them (alpha untouched) removes it.
]=]

--[=[
	@within EdgeBleed
	@param editableImage EditableImage -- the image to fix up
	@param rectPosition Vector2 -- top-left of the area to fix up
	@param rectSize Vector2 -- size of that area

	Copies painted colors one pixel out into the fully transparent pixels around them, within the
	given area only.
]=]
local function bleedRect(editableImage: EditableImage, rectPosition: Vector2, rectSize: Vector2)
	local width = rectSize.X
	local height = rectSize.Y
	if width <= 0 or height <= 0 then
		return
	end

	local pixels = editableImage:ReadPixelsBuffer(rectPosition, rectSize)
	local rowStride = width * 4
	local changed = false

	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local i = (y * width + x) * 4
			if buffer.readu8(pixels, i + 3) == 0 then
				local source = nil
				if x > 0 and buffer.readu8(pixels, i - 1) > 0 then
					source = i - 4
				elseif x < width - 1 and buffer.readu8(pixels, i + 7) > 0 then
					source = i + 4
				elseif y > 0 and buffer.readu8(pixels, i - rowStride + 3) > 0 then
					source = i - rowStride
				elseif y < height - 1 and buffer.readu8(pixels, i + rowStride + 3) > 0 then
					source = i + rowStride
				end

				if source then
					buffer.writeu8(pixels, i, buffer.readu8(pixels, source))
					buffer.writeu8(pixels, i + 1, buffer.readu8(pixels, source + 1))
					buffer.writeu8(pixels, i + 2, buffer.readu8(pixels, source + 2))
					changed = true
				end
			end
		end
	end

	if changed then
		editableImage:WritePixelsBuffer(rectPosition, rectSize, pixels)
	end
end

--[=[
	@within EdgeBleed
	@param editableImage EditableImage -- the image to fix up

	Copies painted colors one pixel out into the fully transparent pixels around them.
]=]
local function bleed(editableImage: EditableImage)
	bleedRect(editableImage, Vector2.zero, editableImage.Size)
end

return {
	bleed = bleed,
	bleedRect = bleedRect,
}

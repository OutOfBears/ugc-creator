export type AssetBoundingBox = {
	-- vars
	lo: Vector3,
	hi: Vector3,
	-- methods
	extent: (self: AssetBoundingBox) -> Vector3,
	center: (self: AssetBoundingBox) -> Vector3,
	expand: (self: AssetBoundingBox, point: Vector3) -> (),
	combine: (self: AssetBoundingBox, otherBox: AssetBoundingBox) -> (),
}

--[=[
	@class AssetBoundingBox

	An axis-aligned box that starts inverted — `lo` at `+inf`, `hi` at `-inf` — so the first
	[AssetBoundingBox:expand] snaps it onto that point rather than stretching from the origin.
]=]
local function AssetBoundingBox(): AssetBoundingBox
	local object = {} :: AssetBoundingBox

	object.lo = Vector3.new(math.huge, math.huge, math.huge)
	object.hi = Vector3.new(-math.huge, -math.huge, -math.huge)

	--[=[
		@within AssetBoundingBox
		@return Vector3 -- the size of the box
	]=]
	function object:extent(): Vector3
		return self.hi - self.lo
	end

	--[=[
		@within AssetBoundingBox
		@return Vector3 -- the centre of the box
	]=]
	function object:center(): Vector3
		return (self.hi + self.lo) / 2
	end

	--[=[
		@within AssetBoundingBox
		@param point Vector3 -- the point the box must contain
	]=]
	function object:expand(point: Vector3)
		self.lo = Vector3.new(math.min(self.lo.X, point.X), math.min(self.lo.Y, point.Y), math.min(self.lo.Z, point.Z))

		self.hi = Vector3.new(math.max(self.hi.X, point.X), math.max(self.hi.Y, point.Y), math.max(self.hi.Z, point.Z))
	end

	--[=[
		@within AssetBoundingBox
		@param otherBox AssetBoundingBox -- the box to merge into this one
	]=]
	function object:combine(otherBox: AssetBoundingBox)
		self:expand(otherBox.lo)
		self:expand(otherBox.hi)
	end

	return object
end

return AssetBoundingBox

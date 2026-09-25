--[=[
	@class GeometryUtil

	Oriented-bounding-box, line-clipping and polygon queries shared by the brush, sticker and
	mesh-editing tools. Pure math — nothing here touches the DataModel.
]=]

local EPSILON = 1e-3

--[=[
	@within GeometryUtil
	@param cframe CFrame -- the box's centre and orientation
	@param size Vector3 -- the box's full extents
	@return { Vector3 } -- the eight corners, in world space

	Corner order is `-X-Y-Z`, `+X-Y-Z`, `-X-Y+Z`, `+X-Y+Z`, then the same four at `+Y`.
]=]
local function obbCorners(cframe: CFrame, size: Vector3): { Vector3 }
	local halfSize = size / 2

	local localCorners = {
		Vector3.new(-halfSize.X, -halfSize.Y, -halfSize.Z),
		Vector3.new(halfSize.X, -halfSize.Y, -halfSize.Z),
		Vector3.new(-halfSize.X, -halfSize.Y, halfSize.Z),
		Vector3.new(halfSize.X, -halfSize.Y, halfSize.Z),
		Vector3.new(-halfSize.X, halfSize.Y, -halfSize.Z),
		Vector3.new(halfSize.X, halfSize.Y, -halfSize.Z),
		Vector3.new(-halfSize.X, halfSize.Y, halfSize.Z),
		Vector3.new(halfSize.X, halfSize.Y, halfSize.Z),
	}

	local worldCorners = {}
	for index, corner in localCorners do
		worldCorners[index] = cframe:PointToWorldSpace(corner)
	end

	return worldCorners
end

--[=[
	@within GeometryUtil
	@param part MeshPart -- the part to take the box from
	@return { Vector3 } -- the eight world-space corners of the part's oriented bounding box
]=]
local function obbCornersFromPart(part: MeshPart): { Vector3 }
	return obbCorners(part.CFrame, part.Size)
end

--[=[
	@within GeometryUtil
	@param corners { Vector3 } -- points to project
	@param axis Vector3 -- the axis to project onto
	@return number -- the smallest projection
	@return number -- the largest projection
]=]
local function projectToAxis(corners: { Vector3 }, axis: Vector3): (number, number)
	local minProjection = math.huge
	local maxProjection = -math.huge

	for _, corner in corners do
		local projection = corner:Dot(axis)
		minProjection = math.min(minProjection, projection)
		maxProjection = math.max(maxProjection, projection)
	end

	return minProjection, maxProjection
end

--[=[
	@within GeometryUtil
	@param part MeshPart -- the first box
	@param cframe CFrame -- the second box's centre and orientation
	@param size Vector3 -- the second box's full extents
	@return boolean -- true if the two boxes overlap

	Separating-axis test across four axes — the three of `part` plus the second box's look
	vector. That is deliberately fewer axes than a complete SAT, which can report an overlap for
	boxes that only touch at an edge; it is what the sticker and kitbash placement checks want.
]=]
local function testObbCollision(part: MeshPart, cframe: CFrame, size: Vector3): boolean
	local corners1 = obbCornersFromPart(part)
	local corners2 = obbCorners(cframe, size)

	local axes = {
		part.CFrame.RightVector,
		part.CFrame.UpVector,
		part.CFrame.LookVector,
		cframe.LookVector,
	}

	for _, axis in axes do
		local min1, max1 = projectToAxis(corners1, axis)
		local min2, max2 = projectToAxis(corners2, axis)

		if max1 < min2 or max2 < min1 then
			return false
		end
	end

	return true
end

--[=[
	@within GeometryUtil
	@param from Vector2 -- the segment's start
	@param to Vector2 -- the segment's end
	@param xMin number -- the rectangle's left edge
	@param yMin number -- the rectangle's bottom edge
	@param xMax number -- the rectangle's right edge
	@param yMax number -- the rectangle's top edge
	@return Vector2? -- the clipped start, or nil if the segment misses the rectangle entirely
	@return Vector2? -- the clipped end

	Liang–Barsky clip of a 2D segment against an axis-aligned rectangle.
]=]
local function clipLineToRectangle(
	from: Vector2,
	to: Vector2,
	xMin: number,
	yMin: number,
	xMax: number,
	yMax: number
): (Vector2?, Vector2?)
	local dx = to.X - from.X
	local dy = to.Y - from.Y

	local t0, t1 = 0, 1

	local function clip(p: number, q: number): boolean
		if p == 0 then
			return q >= 0
		end

		local r = q / p
		if p < 0 then
			if r > t1 then
				return false
			end
			if r > t0 then
				t0 = r
			end
		else
			if r < t0 then
				return false
			end
			if r < t1 then
				t1 = r
			end
		end

		return true
	end

	if not clip(-dx, from.X - xMin) then
		return nil, nil
	end
	if not clip(dx, xMax - from.X) then
		return nil, nil
	end
	if not clip(-dy, from.Y - yMin) then
		return nil, nil
	end
	if not clip(dy, yMax - from.Y) then
		return nil, nil
	end

	if t0 > t1 then
		return nil, nil
	end

	return from + (to - from) * t0, from + (to - from) * t1
end

--[=[
	@within GeometryUtil
	@param point Vector2 -- the point to rotate
	@param pivot Vector2 -- the point to rotate around
	@param angleDegrees number -- the rotation, counter-clockwise
	@return Vector2 -- the rotated point
]=]
local function rotatePoint(point: Vector2, pivot: Vector2, angleDegrees: number): Vector2
	local angleRadians = math.rad(angleDegrees)
	local sin = math.sin(angleRadians)
	local cos = math.cos(angleRadians)

	local x = point.X - pivot.X
	local y = point.Y - pivot.Y

	return Vector2.new(x * cos - y * sin + pivot.X, x * sin + y * cos + pivot.Y)
end

--[=[
	@within GeometryUtil
	@param point Vector3 -- the point to measure
	@param planeNormal Vector3 -- the plane's normal
	@param planePoint Vector3 -- any point on the plane
	@return number -- distance, negative behind the plane
]=]
local function signedDistanceToPlane(point: Vector3, planeNormal: Vector3, planePoint: Vector3): number
	return planeNormal:Dot(point - planePoint)
end

--[=[
	@within GeometryUtil
	@param point Vector3 -- the point to project
	@param planeNormal Vector3 -- the plane's normal
	@param planePoint Vector3 -- any point on the plane
	@return Vector3 -- the point projected onto the plane
]=]
local function closestPointOnPlane(point: Vector3, planeNormal: Vector3, planePoint: Vector3): Vector3
	local distance = -signedDistanceToPlane(point, planeNormal, planePoint)

	return point + planeNormal.Unit * distance
end

--[=[
	@within GeometryUtil
	@param point Vector3 -- the point to project
	@param lineStart Vector3 -- the segment's start
	@param lineEnd Vector3 -- the segment's end
	@return Vector3 -- the closest point on the segment
	@return number -- how far along the segment that point sits, from 0 to 1
]=]
local function closestPointOnSegment(point: Vector3, lineStart: Vector3, lineEnd: Vector3): (Vector3, number)
	local lineVector = lineEnd - lineStart
	local length = lineVector.Magnitude
	local direction = lineVector.Unit

	local distance = math.clamp((point - lineStart):Dot(direction), 0, length)

	return lineStart + direction * distance, distance / length
end

--[=[
	@within GeometryUtil
	@param polygonVerts { Vector2 } -- the polygon's vertices, in order
	@param point Vector2 -- the point to test
	@return boolean -- true if the point is strictly inside

	Jordan curve (even-odd) test. Points exactly on an edge are unreliable here — pair it with
	[GeometryUtil.isPointOnPolygonEdge] when that matters.
]=]
local function isPointInPolygon(polygonVerts: { Vector2 }, point: Vector2): boolean
	local isInside = false
	local numVerts = #polygonVerts

	for i = 1, numVerts do
		local j = if i == 1 then numVerts else i - 1

		if
			((polygonVerts[i].Y > point.Y) ~= (polygonVerts[j].Y > point.Y))
			and (
				point.X
				< (polygonVerts[j].X - polygonVerts[i].X)
						* (point.Y - polygonVerts[i].Y)
						/ (polygonVerts[j].Y - polygonVerts[i].Y)
					+ polygonVerts[i].X
			)
		then
			isInside = not isInside
		end
	end

	return isInside
end

--[=[
	@within GeometryUtil
	@param point Vector2 -- the point to test
	@param lineStart Vector2 -- the segment's start
	@param lineEnd Vector2 -- the segment's end
	@return boolean -- true if the point lies on the segment, within a 1e-3 cross-product tolerance
]=]
local function isPointOnSegment(point: Vector2, lineStart: Vector2, lineEnd: Vector2): boolean
	local crossProduct = (point.Y - lineStart.Y) * (lineEnd.X - lineStart.X)
		- (point.X - lineStart.X) * (lineEnd.Y - lineStart.Y)

	if math.abs(crossProduct) > EPSILON then
		return false
	end

	local dotProduct = (point.X - lineStart.X) * (lineEnd.X - lineStart.X)
		+ (point.Y - lineStart.Y) * (lineEnd.Y - lineStart.Y)
	if dotProduct < 0 then
		return false
	end

	local lineLengthSquared = (lineEnd.X - lineStart.X) * (lineEnd.X - lineStart.X)
		+ (lineEnd.Y - lineStart.Y) * (lineEnd.Y - lineStart.Y)
	if dotProduct > lineLengthSquared then
		return false
	end

	return true
end

--[=[
	@within GeometryUtil
	@param polygonVerts { Vector2 } -- the polygon's vertices, in order
	@param point Vector2 -- the point to test
	@return boolean -- true if the point lies on any edge
]=]
local function isPointOnPolygonEdge(polygonVerts: { Vector2 }, point: Vector2): boolean
	local numVerts = #polygonVerts

	for i = 1, numVerts do
		local j = if i == 1 then numVerts else i - 1

		if isPointOnSegment(point, polygonVerts[i], polygonVerts[j]) then
			return true
		end
	end

	return false
end

--[=[
	@within GeometryUtil
	@param polygonVerts { Vector2 } -- the polygon's vertices, in order
	@param point Vector2 -- a point outside the polygon
	@return Vector2 -- the closest point on the polygon's boundary
]=]
local function projectPointToPolygon(polygonVerts: { Vector2 }, point: Vector2): Vector2
	local minDist = math.huge
	local numVerts = #polygonVerts
	local closestPoint = Vector2.zero

	for i = 1, numVerts do
		local j = if i == 1 then numVerts else i - 1

		local a = point.X - polygonVerts[i].X
		local b = point.Y - polygonVerts[i].Y
		local c = polygonVerts[j].X - polygonVerts[i].X
		local d = polygonVerts[j].Y - polygonVerts[i].Y

		local dot = a * c + b * d
		local lengthSquared = c * c + d * d
		local cosTheta = dot / lengthSquared

		local closestPointToSide
		if cosTheta < 0 then
			closestPointToSide = Vector2.new(polygonVerts[i].X, polygonVerts[i].Y)
		elseif cosTheta > 1 then
			closestPointToSide = Vector2.new(polygonVerts[j].X, polygonVerts[j].Y)
		else
			closestPointToSide = Vector2.new(polygonVerts[i].X + cosTheta * c, polygonVerts[i].Y + cosTheta * d)
		end

		local dist = (point - closestPointToSide).Magnitude
		if dist < minDist then
			closestPoint = closestPointToSide
			minDist = dist
		end
	end

	return closestPoint
end

--[=[
	@within GeometryUtil
	@param point Vector2 -- the point to clamp
	@param polygonVerts { Vector2 } -- the polygon's vertices, in order
	@return Vector2 -- the point itself if it is inside or on the boundary, otherwise the nearest boundary point
]=]
local function closestPointInPolygon(point: Vector2, polygonVerts: { Vector2 }): Vector2
	if isPointInPolygon(polygonVerts, point) then
		return point
	end

	if isPointOnPolygonEdge(polygonVerts, point) then
		return point
	end

	return projectPointToPolygon(polygonVerts, point)
end

--[=[
	@within GeometryUtil
	@param planeNormal Vector3 -- the polygon's plane normal
	@param point Vector3 -- the point to clamp
	@param polygonVerts { Vector3 } -- the polygon's vertices, in order and coplanar
	@return Vector3 -- the nearest point that lies within the polygon

	Projects onto the polygon's plane, solves in 2D, then lifts the answer back into 3D.
]=]
local function closestPointInPolygon3d(planeNormal: Vector3, point: Vector3, polygonVerts: { Vector3 }): Vector3
	local projected = closestPointOnPlane(point, planeNormal, polygonVerts[1])

	local planeXVector = (polygonVerts[1] - polygonVerts[2]).Unit
	local planeYVector = (planeNormal:Cross(planeXVector)).Unit

	local polygonVerts2d = {}
	for index, vertPosition in polygonVerts do
		local difference = vertPosition - projected
		polygonVerts2d[index] = Vector2.new(difference:Dot(planeXVector), difference:Dot(planeYVector))
	end

	local closestPoint2d = closestPointInPolygon(Vector2.zero, polygonVerts2d)

	return projected + planeXVector * closestPoint2d.X + planeYVector * closestPoint2d.Y
end

return {
	obbCorners = obbCorners,
	obbCornersFromPart = obbCornersFromPart,
	projectToAxis = projectToAxis,
	testObbCollision = testObbCollision,
	clipLineToRectangle = clipLineToRectangle,
	rotatePoint = rotatePoint,
	signedDistanceToPlane = signedDistanceToPlane,
	closestPointOnPlane = closestPointOnPlane,
	closestPointOnSegment = closestPointOnSegment,
	isPointInPolygon = isPointInPolygon,
	isPointOnSegment = isPointOnSegment,
	isPointOnPolygonEdge = isPointOnPolygonEdge,
	projectPointToPolygon = projectPointToPolygon,
	closestPointInPolygon = closestPointInPolygon,
	closestPointInPolygon3d = closestPointInPolygon3d,
}

-- https://create.roblox.com/store/asset/236384347/Bezier-Module
-- Bezier
-- Crazyman32
-- April 1, 2015
--
-- NOTE: This was designed for higher-order bezier curves. However,
--	has been optimized for quadratic and cubic cases. Curves of
--	any degree can be calculated, but are not optimized above the
--	cubic case.
--
-- More info on Bezier Curves:
-- http://en.wikipedia.org/wiki/Bezier_curve
-- http://en.wikipedia.org/wiki/De_Casteljau%27s_algorithm
--
-- I recommend reading the Properties section for the first Wiki link
-- This Bezier module was originally designed for my Bezier Path Plugin:
-- http://www.roblox.com/item.aspx?id=232918839
--

--[=[
	@class Bezier

	Computes points and paths along a Bezier curve of any degree, optimized for the
	quadratic (3-point) and cubic (4-point) cases. Build one with [Bezier.new] and reuse it
	rather than recreating an object for the same set of control points.
]=]

export type Bezier = {
	Get: (self: Bezier, ratio: number, clampRatio: boolean?) -> Vector3,
	GetLength: (self: Bezier, step: number?) -> number,
	GetPath: (self: Bezier, step: number) -> { Vector3 },
	GetPathByNumberSegments: (self: Bezier, numSegments: number) -> { Vector3 },
	GetPathBySegmentLength: (self: Bezier, segmentLength: number) -> { Vector3 },
	GetPoints: (self: Bezier) -> { Vector3 },
}
type Point = {
	[number]: number,
	ToVector3: (Point) -> Vector3,
	Lerp: (Point, Point, number) -> Vector3,
}

local Bezier = {}
Bezier.__index = Bezier

local V3 = Vector3.new
local lerpV3 = V3().Lerp

-- Create mutable pseudo-Vector3 points:
local function createPoint(v3: Vector3)
	local point: Point = { v3.X, v3.Y, v3.Z }

	function point:ToVector3()
		return V3(self[1], self[2], self[3])
	end

	function point:Lerp(other, ratio)
		return lerpV3(self:ToVector3(), other:ToVector3(), ratio)
	end

	return point
end

--[=[
	@within Bezier
	@param ... Vector3 -- ordered control points; at least 3 are required
	@return Bezier
]=]
function Bezier.new(...: Vector3): Bezier
	local points = { ... } :: { Vector3 }
	assert(#points >= 3, "Must have at least 3 points")

	local isQuadratic = (#points == 3)
	local isCubic = (#points == 4)

	local length = nil

	local bezier: Bezier = {}
	local lines = {}

	local numLines = 0
	local finalLine = nil

	if not isQuadratic and not isCubic then
		for i = 1, #points - 1 do
			local p1 = createPoint(points[i])
			local p2 = createPoint(points[i + 1])
			local line = { p1, p2, createPoint(p1 :: any) }

			lines[#lines + 1] = line
		end

		local relativeLines = lines
		for n = #lines, 2, -1 do
			local newLines = {}

			for i = 1, n - 1 do
				local l1, l2 = relativeLines[i], relativeLines[i + 1]
				local line = { l1[3], l2[3], createPoint(l1[3] :: any) }

				newLines[i] = line
				lines[#lines + 1] = line
			end

			relativeLines = newLines
		end

		finalLine = relativeLines[1]
		numLines = #lines
	end

	local bezierGet: (self: Bezier, ratio: number, clampRatio: boolean?) -> Vector3
	local exactLength: (() -> number?)? = nil
	if isQuadratic then
		local p0, p1, p2 = points[1], points[2], points[3]

		bezierGet = function(_, ratio, clampRatio)
			if clampRatio then
				ratio = (ratio < 0 and 0 or ratio > 1 and 1 or ratio)
			end

			return (1 - ratio) * (1 - ratio) * p0 + 2 * (1 - ratio) * ratio * p1 + ratio * ratio * p2
		end

		-- Exact arc length of the quadratic curve. B'(t) = 2(s*t - a), so the length is the
		-- closed-form integral of its magnitude (see Hornus, members.loria.fr/SHornus/quadratic-arc-length.html).
		-- The antiderivative breaks down when the controls are collinear, so those cases return
		-- nil and GetLength falls back to sampling.
		exactLength = function()
			local a = p0 - p1
			local s = p0 - 2 * p1 + p2

			local alpha = s:Dot(s)
			if alpha < 1e-8 then
				return (p0 - p2).Magnitude
			end

			local beta = -2 * s:Dot(a)
			local gamma = a:Dot(a)

			local discriminant = 4 * alpha * gamma - beta * beta
			if discriminant < 1e-8 then
				return nil
			end

			local sqrtAlpha = math.sqrt(alpha)
			local logCoefficient = discriminant / (8 * alpha * sqrtAlpha)

			local function antiderivative(t: number): number
				local f = math.sqrt(alpha * t * t + beta * t + gamma)
				return (2 * alpha * t + beta) / (4 * alpha) * f
					+ logCoefficient * math.log(2 * alpha * t + beta + 2 * sqrtAlpha * f)
			end

			return 2 * (antiderivative(1) - antiderivative(0))
		end
	elseif isCubic then
		local p0, p1, p2, p3 = points[1], points[2], points[3], points[4]
		bezierGet = function(_, ratio, clampRatio)
			local f = ratio :: any

			if clampRatio then
				f = (f < 0 and 0 or f > 1 and 1 or f)
			end

			return (
				(1 - f) * (1 - f) * (1 - f) * p0
				+ 3 * (1 - f) * (1 - f) * f * p1
				+ 3 * (1 - f) * f * f * p2
				+ f * f * f * p3
			) :: any
		end
	else
		bezierGet = function(_, ratio, clampRatio)
			if clampRatio then
				ratio = (ratio < 0 and 0 or ratio > 1 and 1 or ratio)
			end

			for i = 1, numLines do
				local line = lines[i]
				local mid = line[1]:Lerp(line[2], ratio)
				local pt = line[3]
				pt[1], pt[2], pt[3] = mid.X, mid.Y, mid.Z
			end

			return finalLine[3]:ToVector3()
		end
	end

	--[=[
		@within Bezier
		@function Get
		@param ratio number -- position along the curve, from 0 (start) to 1 (end)
		@param clampRatio boolean? -- when true, clamps ratio into the [0, 1] range
		@return Vector3 -- the point on the curve at ratio
	]=]
	bezier.Get = bezierGet

	--[=[
		@within Bezier
		@param step number? -- ratio step for the sampled fallback (cubic and higher); ignored for the exact quadratic case. Defaults to 0.1
		@return number -- length of the curve: exact for a quadratic, a sampled approximation otherwise
	]=]
	function bezier:GetLength(step: number?): number
		if length then
			return length
		end

		if exactLength then
			local exact = exactLength()
			if exact then
				length = exact
				return length
			end
		end

		local sampleStep = step or 0.1
		local l = 0
		local prev = self:Get(0)

		local t = sampleStep
		while t < 1 do
			local point = self:Get(t)
			l += (point - prev).Magnitude
			prev = point
			t += sampleStep
		end
		l += (self:Get(1) - prev).Magnitude

		length = l
		return length
	end

	--[=[
		@within Bezier
		@param step number -- ratio increment between samples, within the open interval (0, 1)
		@return { Vector3 } -- points sampled along the curve
	]=]
	function bezier:GetPath(step: number): { Vector3 }
		assert(type(step) == "number", "Must provide a step increment")
		-- Check step domain is within interval (0.0, 1.0):
		assert(step > 0 and step < 1, "Step out of domain; should be between 0 and 1 (exclusive)")

		local path = {}
		local lastI = 0

		for i = 0, 1, step do
			lastI = i
			path[#path + 1] = self:Get(i)
		end

		-- In case 'step' didn't fill path fully, properly handle last remaining point:
		if lastI < 1 then
			local overrideLast = ((1 - lastI) < (step * 0.5))
			path[#path + (overrideLast and 0 or 1)] = self:Get(1)
		end

		return path
	end

	--[=[
		@within Bezier
		@param numSegments number -- number of evenly-spaced segments to divide the curve into
		@return { Vector3 } -- points sampled along the curve
	]=]
	function bezier:GetPathByNumberSegments(numSegments: number): { Vector3 }
		assert(type(numSegments) == "number", "Must provide number of segments")
		assert(numSegments > 0, "Number of segments must be greater than 0")

		return self:GetPath(1 / numSegments)
	end

	--[=[
		@within Bezier
		@param segmentLength number -- approximate world-space length of each segment
		@return { Vector3 } -- points sampled along the curve
	]=]
	function bezier:GetPathBySegmentLength(segmentLength: number): { Vector3 }
		assert(type(segmentLength) == "number", "Must provide a segment length")
		assert(segmentLength > 0, "Segment length must be greater than 0")

		local totalLength = self:GetLength() :: any
		local numSegments = totalLength / segmentLength

		return self:GetPathByNumberSegments(math.floor(numSegments + 0.5))
	end

	--[=[
		@within Bezier
		@return { Vector3 } -- the control points passed to [Bezier.new]
	]=]
	function bezier:GetPoints(): { Vector3 }
		return points
	end

	return bezier
end

return Bezier

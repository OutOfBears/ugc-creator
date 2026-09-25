--!native
local GaussLegendre = require(script.Parent.GaussLegendre)
local Squad = require(script.Parent.Squad)

local MAX_NEWTON_ITERATIONS = 16
local EPSILON = 1e-4

export type Point = Vector3 | Vector2
export type Transform = { Point }

local Spline = {}
Spline.__index = Spline

export type Spline = typeof(setmetatable({
	rot0 = Vector3.zero :: Point?,
	rot1 = Vector3.zero :: Point?,
	rot2 = Vector3.zero :: Point?,
	rot3 = Vector3.zero :: Point?,
	length = 0 :: number?,
	-- Coefficient vectors for position/velocity/acceleration polynomials
	a = { Vector3.zero } :: Transform,
	b = { Vector3.zero } :: Transform,
	c = { Vector3.zero } :: Transform,
	d = { Vector3.zero } :: Transform,
	arcLengthParamsLUT = nil :: { number }?,
}, Spline))

function Spline.new(trans0: Transform, trans1: Transform, trans2: Transform, trans3: Transform, alpha, tension)
	-- Parameterize
	-- https://qroph.github.io/2018/07/30/smooth-paths-using-catmull-rom-splines.html
	local pos0 = trans0[1] :: any
	local pos1 = trans1[1] :: any
	local pos2 = trans2[1] :: any
	local pos3 = trans3[1] :: any

	local pos1_pos0 = pos1 - pos0 :: any
	local pos2_pos1 = pos2 - pos1 :: any
	local pos3_pos2 = pos3 - pos2 :: any

	local a, b, c
	local t0 = 0
	local t1 = pos1_pos0.Magnitude ^ alpha + t0
	local t2 = pos2_pos1.Magnitude ^ alpha + t1
	local t3 = pos3_pos2.Magnitude ^ alpha + t2

	local scalar = (1 - tension) * (t2 - t1)

	local m1 = scalar * (pos1_pos0 / (t1 - t0) - (pos2 - pos0) / (t2 - t0) + pos2_pos1 / (t2 - t1))
	local m2 = scalar * (pos2_pos1 / (t2 - t1) - (pos3 - pos1) / (t3 - t1) + pos3_pos2 / (t3 - t2))

	a = 2 * -pos2_pos1 + m1 + m2
	b = 3 * pos2_pos1 - 2 * m1 - m2
	c = m1

	local self = setmetatable({
		-- Rotations (nil if VectorCatRom)
		rot0 = trans0[2],
		rot1 = trans1[2],
		rot2 = trans2[2],
		rot3 = trans3[2],

		length = nil,

		-- Coefficient vectors for position/velocity/acceleration polynomials
		a = a :: Transform,
		b = b :: Transform,
		c = c :: Transform,
		d = pos1 :: Transform,

		arcLengthParamsLUT = nil,
	}, Spline) :: Spline

	self.length = self:SolveLength()

	return self
end

function Spline.fromPoint<T>(trans: Transform): Spline
	local pos = trans[1]
	local zero = (pos :: any) * 0

	return setmetatable({
		rot0 = trans[2] :: any,

		length = 0,

		a = zero :: any,
		b = zero :: any,
		c = zero :: any,
		d = trans[1] :: any,

		arcLengthParamsLUT = nil,
	}, Spline)
end

function Spline.fromLine(trans0: Transform, trans1: Transform, trans2: Transform, trans3: Transform): Spline
	local pos1 = trans1[1]
	local zero = (pos1 :: any) * 0
	local pos2_pos1 = trans2[1] - (pos1 :: any)

	return setmetatable({
		rot0 = trans0[2] :: any,
		rot1 = trans1[2] :: any,
		rot2 = trans2[2] :: any,
		rot3 = trans3[2] :: any,

		length = pos2_pos1.Magnitude :: any,

		a = zero :: any,
		b = zero :: any,
		c = pos2_pos1 :: any,
		d = pos1 :: any,

		arcLengthParamsLUT = nil,
	}, Spline)
end

-- Methods
function Spline.SolvePosition(self: Spline, t: number): Point
	-- r(t) using Horner's method
	return self.d + t * (self.c + t * (self.b + t * self.a :: any))
end

function Spline.SolveVelocity(self: Spline, t: number): Point
	-- r'(t) using Horner's method
	return self.c + t * (2 * self.b :: any + t * 3 * self.a :: any)
end

function Spline.SolveAcceleration(self: Spline, t: number): Point
	-- r''(t)
	return 6 * self.a :: any * t + 2 * self.b :: any
end

function Spline.SolveTangent(self: Spline, t: number): Point
	-- T(t) = r'(t) / ||r'(t)||
	return (self:SolveVelocity(t) :: any).Unit
end

function Spline.SolveNormal(self: Spline, t: number): Point
	-- N(t) = T'(t) / ||T'(t)||
	-- The return is equivalent to N(t) when the derivatives are carried out.
	-- In particular, the vector being unitized is T'(t) * ||r'(t)|| ^ 3, but
	-- the ||r'(t)|| ^ 3 scaling doesn't affect the result because we unitize it
	-- anyway. This scaled version is faster to compute.
	local rp = self:SolveVelocity(t) -- p for prime (1st deriv.)
	local rpp = self:SolveAcceleration(t) -- pp for prime prime (2nd deriv.)
	return (rpp * (rp :: any).Magnitude ^ 2 - rp * (rpp :: any):Dot(rp)).Unit
end

function Spline.SolveBinormal(self: Spline, t: number): Point
	-- T(t) x N(t)
	return (self:SolveTangent(t) :: any):Cross(self:SolveNormal(t))
end

function Spline.SolveCurvature(self: Spline, t: number): (number, Point)
	local rp = self:SolveVelocity(t) :: any
	local rpp = self:SolveAcceleration(t)
	local rpMag = rp.Magnitude
	local tangentp = rpp / rpMag - rp * rp:Dot(rpp) / rpMag ^ 3

	-- Curvature = ||T'(t)|| / ||r'(t)||
	-- N(t) is the direction of curvature
	local curvature = tangentp.Magnitude / rpMag
	local unitNormal = tangentp.Unit
	return curvature, unitNormal
end

function Spline.SolveCFrame(self: Spline, t: number): CFrame
	local position = self:SolvePosition(t) :: any
	local tangent = self:SolveVelocity(t) :: any

	if tangent.Magnitude == 0 then
		local rot = self.rot0 :: any
		if rot then
			return CFrame.new(position.X, position.Y, position.Z, rot[2], rot[3], rot[4], rot[1])
		else
			return CFrame.new(position)
		end
	end

	return CFrame.lookAt(position, position + tangent)
end

function Spline.SolveRotCFrame(self: Spline, t: number): CFrame
	local rot0 = self.rot0 :: any
	if rot0 then -- CFrameCatRom
		local rot1 = self.rot1 :: any
		if rot1 then
			local pos = self:SolvePosition(t) :: any
			local qw, qx, qy, qz = Squad(rot0, rot1, self.rot2 :: any, self.rot3 :: any, t)
			return CFrame.new(pos.X, pos.Y, pos.Z, qx, qy, qz, qw)
		else -- 1 point
			return self:SolveCFrame(t)
		end
	else -- VectorCatRom
		return self:SolveCFrame(t)
	end
end

function Spline.SolveLength(self: Spline, a: number?, b: number?): number
	a = a or 0
	b = b or 1

	if a == 0 and b == 1 and self.length then
		return self.length :: any
	end

	return GaussLegendre.Ten(function(x)
		return (self:SolveVelocity(x) :: any).Magnitude
	end, a :: number, b :: number)
end

-- Reparameterizes s in terms of arc length, i.e. returns the input t that
-- yields the point s of the way along the spline
function Spline:Reparameterize(s: number)
	if s == 0 or s == 1 then
		return s
	elseif self.length == 0 then
		return 0
	end

	local arcLengthParams = self.arcLengthParams
	if arcLengthParams then
		local numIntervals = #self.arcLengthParams - 1
		local intervalIndex = math.floor(s * numIntervals) + 1
		local t = s * numIntervals - intervalIndex + 1
		return arcLengthParams[intervalIndex] :: any * (1 - t) + arcLengthParams[intervalIndex + 1] :: any * t
	else
		return self:_ReparameterizeHybrid(s)
	end
end

-- Performs the actual arc length parameterization
-- s = \int_{0}^{t} ||r'(t)||dt = F(t) - F(0) = F(t)
-- where t is solved as the root-finding problem F(t) - s = 0.
function Spline:_ReparameterizeHybrid(s: number)
	if s == 0 or s == 1 then
		return s
	elseif self.length == 0 then
		return 0
	end

	-- Hybrid of Newton's method and bisection
	-- https://www.geometrictools.com/Documentation/MovingAlongCurveSpecifiedSpeed.pdf
	local integrand = function(x)
		return self:SolveVelocity(x).Magnitude
	end

	local t = s
	local lower = 0
	local upper = 1

	for _ = 1, MAX_NEWTON_ITERATIONS do
		local f = GaussLegendre.Ten(integrand, 0, t) / self.length - s
		if math.abs(f) < EPSILON then
			return t
		end

		local g = ((self:SolveVelocity(t :: any)) :: any).Magnitude / self.length
		local candidate = t - f / g

		if f > 0 then
			-- Solution is below the current t
			upper = t
			t = candidate <= lower and (upper + lower) / 2 or candidate
		else
			-- Solution is above the current t
			lower = t
			t = candidate >= upper and (upper + lower) / 2 or candidate
		end
	end

	warn("Failed to reparameterize; falling back to input")
	return s
end

-- Precomputes a lookup table of numIntervals + 1 evenly spaced arc length
-- parameters that are used to piecewise linearly interpolate the real
-- parameterization function
function Spline:_PrecomputeArcLengthParams(numIntervals: number)
	if self.length == 0 then
		return
	end

	local arcLengthParamsLUT = table.create(numIntervals + 1)
	arcLengthParamsLUT[1] = 0
	arcLengthParamsLUT[numIntervals + 1] = 1
	for i = 2, numIntervals do
		arcLengthParamsLUT[i] = self:_ReparameterizeHybrid((i - 1) / numIntervals)
	end

	self.arcLengthParamsLUT = arcLengthParamsLUT
end

-- START GENERATED METHODS
function Spline.SolveUniformPosition(self: Spline, t: number)
	return self:SolvePosition(self:Reparameterize(t))
end
function Spline.SolveUniformVelocity(self: Spline, t: number)
	return self:SolveVelocity(self:Reparameterize(t))
end
function Spline.SolveUniformAcceleration(self: Spline, t: number)
	return self:SolveAcceleration(self:Reparameterize(t))
end
function Spline.SolveUniformTangent(self: Spline, t: number)
	return self:SolveTangent(self:Reparameterize(t))
end
function Spline.SolveUniformNormal(self: Spline, t: number)
	return self:SolveNormal(self:Reparameterize(t))
end
function Spline.SolveUniformBinormal(self: Spline, t: number)
	return self:SolveBinormal(self:Reparameterize(t))
end
function Spline.SolveUniformCurvature(self: Spline, t: number)
	return self:SolveCurvature(self:Reparameterize(t))
end
function Spline.SolveUniformCFrame(self: Spline, t: number)
	return self:SolveCFrame(self:Reparameterize(t))
end
function Spline.SolveUniformRotCFrame(self: Spline, t: number)
	return self:SolveRotCFrame(self:Reparameterize(t))
end
function Spline.SolveUniformLength(self: Spline, a: number?, b: number?)
	return self:SolveLength(self:Reparameterize(a :: any), self:Reparameterize(b :: any))
end
-- END GENERATED METHODS

return Spline

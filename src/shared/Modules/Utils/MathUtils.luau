--[=[
	@class MathUtils

	Math helpers for gameplay and game-design scaling: interpolation,
	S-curves, easings, and level-based progression formulas.
]=]

local rng = Random.new()

--[=[
	Picks a key from `weights` with probability proportional to its weight.
	Returns nil when the table is empty or all weights are non-positive.

	```lua
	MathUtils.weightedPick({ a = 3, b = 1 }) -- "a" three times as often as "b"
	```

	@within MathUtils
	@param weights { [K]: number } -- map of key to relative weight
	@return K?
]=]
local function weightedPick<K>(weights: { [K]: number }): K?
	local total = 0
	for _, weight in weights do
		total += weight
	end

	if total <= 0 then
		return nil
	end

	local roll = rng:NextNumber(0, total)
	for key, weight in weights do
		roll -= weight
		if roll <= 0 then
			return key
		end
	end

	return nil
end

--[=[
	Squared horizontal (XZ-plane) distance between two points. Ignores Y.

	Cheaper than a real distance — use when only comparing distances against
	each other or a squared threshold (e.g. `d2 < range * range`).

	@within MathUtils
	@param a Vector3
	@param b Vector3
	@return number
]=]
local function horizontalDistSq(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return dx * dx + dz * dz
end

--[=[
	Projects `distance` studs from `origin` along the flat direction represented
	by `yaw`.

	@within MathUtils
	@param origin Vector3
	@param yaw number -- radians
	@param distance number
	@return Vector3
]=]
local function pointAlongYaw(origin: Vector3, yaw: number, distance: number): Vector3
	local direction = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	return origin + direction * distance
end

--[=[
	Clamps `target` so its horizontal (XZ) offset from `origin` is at most
	`maxDistance`, preserving the target's Y component.

	@within MathUtils
	@param origin Vector3
	@param target Vector3
	@param maxDistance number
	@return Vector3
]=]
local function clampHorizontalDistance(origin: Vector3, target: Vector3, maxDistance: number): Vector3
	local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
	if flat.Magnitude <= maxDistance then
		return target
	end

	return Vector3.new(origin.X, target.Y, origin.Z) + flat.Unit * maxDistance
end

--[=[
	Returns whether `point` falls on the horizontal segment from `startPoint` to
	`endPoint`, with a lateral allowance of `width / 2` studs on either side.

	@within MathUtils
	@param point Vector3
	@param startPoint Vector3
	@param endPoint Vector3
	@param width number
	@return boolean
]=]
local function pointWithinHorizontalSegmentWidth(
	point: Vector3,
	startPoint: Vector3,
	endPoint: Vector3,
	width: number
): boolean
	local flatLine = Vector3.new(endPoint.X - startPoint.X, 0, endPoint.Z - startPoint.Z)
	if flatLine.Magnitude <= 1e-3 then
		return false
	end

	local flatToPoint = Vector3.new(point.X - startPoint.X, 0, point.Z - startPoint.Z)
	local direction = flatLine.Unit
	local progress = flatToPoint:Dot(direction)

	if progress < 0 or progress > flatLine.Magnitude then
		return false
	end

	local lateral = (flatToPoint - direction * progress).Magnitude
	return lateral <= width / 2
end

--[=[
	Inverse of a linear interpolation: returns where `value` falls between
	`a` and `b` as a 0..1 fraction (can extrapolate outside that range).
	Returns 0 when `a == b` to avoid divide-by-zero.

	```lua
	MathUtils.inverseLerp(100, 200, 150) -- 0.5
	```

	@within MathUtils
	@param a number -- range start
	@param b number -- range end
	@param value number -- value to locate within the range
	@return number
]=]
local function inverseLerp(a: number, b: number, value: number): number
	if a == b then
		return 0
	end
	return (value - a) / (b - a)
end

--[=[
	Standard sigmoid: `1 / (1 + e^-x)`. Maps any real number to `(0, 1)`
	with output `0.5` at `x = 0`. For tunable curves, prefer [MathUtils.logistic].

	@within MathUtils
	@param x number
	@return number
]=]
local function sigmoid(x: number): number
	return 1 / (1 + math.exp(-x))
end

--[=[
	Parameterized S-curve. Good for soft caps and difficulty curves.

	```lua
	-- Ramps to ~1000 around level 50.
	MathUtils.logistic(level, 50, 0.1, 1000)
	```

	@within MathUtils
	@param x number -- input value
	@param midpoint number -- x at which output equals max/2
	@param steepness number -- how sharp the transition is
	@param max number -- upper asymptote
	@return number
]=]
local function logistic(x: number, midpoint: number, steepness: number, max: number): number
	return max / (1 + math.exp(-steepness * (x - midpoint)))
end

--[=[
	Smooth Hermite interpolation between `edge0` and `edge1`. Returns 0 below
	`edge0`, 1 above `edge1`, and an S-shaped ramp in between (zero slope at
	both edges). Use for gentle fades and blend masks.

	@within MathUtils
	@param edge0 number -- lower edge
	@param edge1 number -- upper edge
	@param x number -- input value
	@return number
]=]
local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp(inverseLerp(edge0, edge1, x), 0, 1)
	return t * t * (3 - 2 * t)
end

--[=[
	Like [MathUtils.smoothstep] but with zero first AND second derivatives at
	the edges, giving an even smoother ramp. Slightly more expensive.

	@within MathUtils
	@param edge0 number -- lower edge
	@param edge1 number -- upper edge
	@param x number -- input value
	@return number
]=]
local function smootherstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp(inverseLerp(edge0, edge1, x), 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

--[=[
	Quadratic ease-in: slow start, fast end. Input and output in `[0, 1]`.

	@within MathUtils
	@param t number
	@return number
]=]
local function easeInQuad(t: number): number
	return t * t
end

--[=[
	Quadratic ease-out: fast start, slow end. Input and output in `[0, 1]`.

	@within MathUtils
	@param t number
	@return number
]=]
local function easeOutQuad(t: number): number
	return 1 - (1 - t) * (1 - t)
end

--[=[
	Quadratic ease-in-out: slow at both ends, fast in the middle.
	Input and output in `[0, 1]`.

	@within MathUtils
	@param t number
	@return number
]=]
local function easeInOutQuad(t: number): number
	if t < 0.5 then
		return 2 * t * t
	end
	local u = -2 * t + 2
	return 1 - u * u / 2
end

--[=[
	Cubic ease-in: slow start, fast end. More pronounced than the quadratic
	variant. Input and output in `[0, 1]`.

	@within MathUtils
	@param t number
	@return number
]=]
local function easeInCubic(t: number): number
	return t * t * t
end

--[=[
	Cubic ease-out: fast start, slow end. More pronounced than the quadratic
	variant. Input and output in `[0, 1]`.

	@within MathUtils
	@param t number
	@return number
]=]
local function easeOutCubic(t: number): number
	local u = 1 - t
	return 1 - u * u * u
end

--[=[
	Cubic ease-in-out: slow at both ends, fast in the middle. More pronounced
	than the quadratic variant. Input and output in `[0, 1]`.

	@within MathUtils
	@param t number
	@return number
]=]
local function easeInOutCubic(t: number): number
	if t < 0.5 then
		return 4 * t * t * t
	end
	local u = -2 * t + 2
	return 1 - u * u * u / 2
end

--[=[
	Linear progression: `value(level) = base + increment * (level - 1)`.
	Constant rate of growth. Good for small stat bumps per level or
	predictable rewards.

	```lua
	MathUtils.linearScale(5, 100, 10) -- 140
	```

	@within MathUtils
	@param level number
	@param base number -- value at level 1
	@param increment number -- amount added per level
	@return number
]=]
local function linearScale(level: number, base: number, increment: number): number
	return base + increment * (level - 1)
end

--[=[
	Geometric progression: `value(level) = base * growth ^ (level - 1)`.
	Each level multiplies by `growth`; values balloon fast. Good for shop
	costs and XP-to-next-level curves where later levels should hurt.

	```lua
	MathUtils.exponentialScale(5, 100, 1.5) -- 506.25
	```

	@within MathUtils
	@param level number
	@param base number -- value at level 1
	@param growth number -- per-level multiplier
	@return number
]=]
local function exponentialScale(level: number, base: number, growth: number): number
	return base * growth ^ (level - 1)
end

--[=[
	Polynomial progression: `value(level) = base * level ^ exponent`.
	Softer than exponential — growth slows relative to compounding. Use
	`exponent < 1` for diminishing growth, `> 1` for accelerating growth.
	Good for enemy HP / damage scaling that shouldn't explode.

	```lua
	MathUtils.powerScale(10, 50, 1.5) -- ~1581
	```

	@within MathUtils
	@param level number
	@param base number -- coefficient
	@param exponent number -- shape of the curve
	@return number
]=]
local function powerScale(level: number, base: number, exponent: number): number
	return base * level ^ exponent
end

--[=[
	Diminishing-returns curve: `value(level) = base + scale * ln(level)`.
	Grows quickly at low levels, then flattens out. Never plateaus completely
	but gets effectively flat at high levels. Good for soft-capped stats,
	prestige rewards, and mastery bonuses.

	```lua
	MathUtils.logarithmicScale(10, 0, 50) -- ~115
	```

	@within MathUtils
	@param level number
	@param base number -- offset added to the curve
	@param scale number -- multiplier on the logarithm
	@return number
]=]
local function logarithmicScale(level: number, base: number, scale: number): number
	return base + scale * math.log(level)
end

local function raySphereEntry(rel: Vector3, u: Vector3, radius: number): number?
	local b = rel:Dot(u)
	local disc = b * b - (rel:Dot(rel) - radius * radius)
	if disc < 0 then
		return nil
	end

	local t = -b - math.sqrt(disc)
	return if t >= 0 then t else nil
end

--[=[
	Entry intersection between a ray and a vertical (Y-axis-aligned) capsule.
	The capsule is the segment `center ± halfHeight` on Y, inflated by `radius`
	(sphere caps included). Returns the distance along the ray to the surface
	entry point, or nil when the ray misses or the entry lies beyond `maxDist`.
	A ray starting inside the capsule returns `0` only when it points toward
	the capsule center — shooting away from something you overlap is a miss,
	mirroring raycasts, which never hit a part they start inside.

	```lua
	local t = MathUtils.rayToVerticalCapsule(origin, dir, 100, torsoPos, 2.5, 1.5)
	local hitPos = t and origin + dir.Unit * t
	```

	@within MathUtils
	@param origin Vector3 -- ray start
	@param direction Vector3 -- ray direction; need not be unit length
	@param maxDist number -- maximum distance along the ray
	@param center Vector3 -- capsule center
	@param halfHeight number -- axis segment half-length
	@param radius number -- capsule radius
	@return number? -- distance along the ray to the entry point, nil on miss
]=]
local function rayToVerticalCapsule(
	origin: Vector3,
	direction: Vector3,
	maxDist: number,
	center: Vector3,
	halfHeight: number,
	radius: number
): number?
	local u = direction.Unit
	local w = origin - center

	-- Origin inside the capsule: hit at 0 only when aiming toward it (raycast parity).
	local nearCapY = if w.Y > 0 then halfHeight else -halfHeight
	local insideBody = w.X * w.X + w.Z * w.Z <= radius * radius and math.abs(w.Y) <= halfHeight
	if insideBody or (w - Vector3.new(0, nearCapY, 0)).Magnitude <= radius then
		return if -w:Dot(u) > 0 then 0 else nil
	end

	-- Cylinder side wall, solved in the XZ plane.
	local a = u.X * u.X + u.Z * u.Z
	if a > 1e-9 then
		local b = 2 * (w.X * u.X + w.Z * u.Z)
		local c = w.X * w.X + w.Z * w.Z - radius * radius
		local disc = b * b - 4 * a * c

		if disc >= 0 then
			local t = (-b - math.sqrt(disc)) / (2 * a)
			if t >= 0 and t <= maxDist and math.abs(w.Y + u.Y * t) <= halfHeight then
				return t
			end
		end
	end

	-- Sphere caps.
	local topT = raySphereEntry(w - Vector3.new(0, halfHeight, 0), u, radius)
	local bottomT = raySphereEntry(w + Vector3.new(0, halfHeight, 0), u, radius)
	local t = if topT and bottomT then math.min(topT, bottomT) else topT or bottomT

	return if t and t <= maxDist then t else nil
end

--[=[
	Builds an orthonormal CFrame at `position` whose RightVector (local +X) equals
	`right`. Handy for orienting instances that align to a direction along their X axis,
	such as Roblox Beam attachments (`WorldAxis`) and Cylinder parts.

	@within MathUtils
	@param position Vector3
	@param right Vector3 -- the desired RightVector; need not be unit length
	@return CFrame
]=]
local function cframeFromRightVector(position: Vector3, right: Vector3): CFrame
	local rightUnit = right.Unit
	local up = if math.abs(rightUnit.Y) < 0.99 then Vector3.yAxis else Vector3.xAxis
	up = (up - rightUnit * rightUnit:Dot(up)).Unit

	return CFrame.fromMatrix(position, rightUnit, up)
end

--[=[
	Builds an orthonormal CFrame at `position` whose UpVector (local +Y) equals `up`.
	Handy for resting an instance flush on a surface so its bottom face sits against the
	surface, aligned to a raycast `Normal`.

	@within MathUtils
	@param position Vector3
	@param up Vector3 -- the desired UpVector; need not be unit length
	@return CFrame
]=]
local function cframeFromUpVector(position: Vector3, up: Vector3): CFrame
	local upUnit = up.Unit
	local right = if math.abs(upUnit.X) < 0.99 then Vector3.xAxis else Vector3.yAxis
	right = (right - upUnit * upUnit:Dot(right)).Unit

	return CFrame.fromMatrix(position, right, upUnit)
end

--[=[
	Uniformly-random world-space point inside `part`'s oriented box volume
	(sampled against `Size`/`CFrame`, ignoring the part's `Shape`).

	@within MathUtils
	@param part BasePart -- the part whose volume to sample
	@return Vector3 -- a random point inside the part
]=]
local function randomPointInPart(part: BasePart): Vector3
	local half = part.Size / 2
	local offset =
		Vector3.new(rng:NextNumber(-half.X, half.X), rng:NextNumber(-half.Y, half.Y), rng:NextNumber(-half.Z, half.Z))
	return (part.CFrame * CFrame.new(offset)).Position
end

return {
	weightedPick = weightedPick,
	horizontalDistSq = horizontalDistSq,
	pointAlongYaw = pointAlongYaw,
	clampHorizontalDistance = clampHorizontalDistance,
	pointWithinHorizontalSegmentWidth = pointWithinHorizontalSegmentWidth,
	inverseLerp = inverseLerp,
	sigmoid = sigmoid,
	logistic = logistic,
	smoothstep = smoothstep,
	smootherstep = smootherstep,
	easeInQuad = easeInQuad,
	easeOutQuad = easeOutQuad,
	easeInOutQuad = easeInOutQuad,
	easeInCubic = easeInCubic,
	easeOutCubic = easeOutCubic,
	easeInOutCubic = easeInOutCubic,
	linearScale = linearScale,
	exponentialScale = exponentialScale,
	powerScale = powerScale,
	logarithmicScale = logarithmicScale,
	rayToVerticalCapsule = rayToVerticalCapsule,
	cframeFromRightVector = cframeFromRightVector,
	cframeFromUpVector = cframeFromUpVector,
	randomPointInPart = randomPointInPart,
}

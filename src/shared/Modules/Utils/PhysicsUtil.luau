--[=[
	@class PhysicsUtil

	Ballistic helpers shared by the projectile system. Both model the same trajectory,
	`position = origin + velocity * t + gravity * t²` — note this drops the conventional ½ on
	the gravity term, so `gravity` here is effectively twice physical acceleration. `launchVelocity`
	is the exact inverse of `projectilePosition`: feed its result back in at `flightTime` and you
	land on the point.
]=]

local function antiGravity(basePart: BasePart, factor: number?)
	if basePart:FindFirstChild("AntiGravity") then
		return
	end

	local gravityFactor = factor or 1
	local antiGrav = Instance.new("BodyForce")
	antiGrav.Name = "AntiGravity"
	antiGrav.Force = Vector3.new(0, basePart:GetMass() * workspace.Gravity * gravityFactor, 0)
	antiGrav.Parent = basePart
end

--[=[
	Sets a part's planar (XZ) assembly velocity to aim toward `target` at
	`speed`, preserving the current Y velocity. No-op when the target is
	horizontally coincident with the part.

	@within PhysicsUtil
	@param basePart BasePart
	@param target Vector3
	@param speed number
]=]
local function setPlanarVelocityToward(basePart: BasePart, target: Vector3, speed: number)
	local offset = target - basePart.Position
	local planar = Vector3.new(offset.X, 0, offset.Z)
	if planar.Magnitude <= 1e-3 then
		return
	end

	basePart.AssemblyLinearVelocity =
		Vector3.new(planar.Unit.X * speed, basePart.AssemblyLinearVelocity.Y, planar.Unit.Z * speed)
end

--[=[
	Sets a part's assembly velocity so it launches from `origin` toward `target`
	with horizontal speed `speed` and vertical speed `up`. No-op when the points
	are horizontally coincident.

	@within PhysicsUtil
	@param basePart BasePart
	@param origin Vector3
	@param target Vector3
	@param speed number
	@param up number
]=]
local function setLaunchVelocityToward(basePart: BasePart, origin: Vector3, target: Vector3, speed: number, up: number)
	local offset = target - origin
	local planar = Vector3.new(offset.X, 0, offset.Z)
	if planar.Magnitude <= 1e-3 then
		return
	end

	basePart.AssemblyLinearVelocity = Vector3.new(planar.Unit.X * speed, up, planar.Unit.Z * speed)
end

--[=[
	Position along a ballistic trajectory `time` seconds after launch.

	@within PhysicsUtil
	@param origin Vector3 -- launch position
	@param velocity Vector3 -- launch velocity
	@param gravity Vector3 -- gravity vector (see the convention note above)
	@param time number -- seconds since launch
	@return Vector3 -- position at that time
]=]
local function projectilePosition(origin: Vector3, velocity: Vector3, gravity: Vector3, time: number): Vector3
	return origin + (velocity * time) + (gravity * time ^ 2)
end

--[=[
	Launch velocity that carries a projectile from `origin` to `target` in exactly `flightTime`
	seconds under `gravity`.

	@within PhysicsUtil
	@param origin Vector3 -- launch position
	@param target Vector3 -- point to land on
	@param gravity Vector3 -- gravity vector (see the convention note above)
	@param flightTime number -- seconds the flight should take
	@return Vector3 -- velocity to launch with
]=]
local function launchVelocity(origin: Vector3, target: Vector3, gravity: Vector3, flightTime: number): Vector3
	return (target - origin) / flightTime - gravity * flightTime
end

return {
	antiGravity = antiGravity,
	setPlanarVelocityToward = setPlanarVelocityToward,
	setLaunchVelocityToward = setLaunchVelocityToward,
	projectilePosition = projectilePosition,
	launchVelocity = launchVelocity,
}

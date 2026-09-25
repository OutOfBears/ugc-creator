--[=[
	@class RaycastUtils

	Helpers for building raycast exclusion lists and params used by projectiles and bullets.
]=]

local params = RaycastParams.new()
local lineOfSightParams = RaycastParams.new()

lineOfSightParams.FilterType = Enum.RaycastFilterType.Exclude
lineOfSightParams.IgnoreWater = true

local function getPointOnGround(from: Vector3, length: number?)
	params.IncludeInstances = { workspace.Map }
	return workspace:Raycast(from, Vector3.new(0, -(length or 20), 0), params)
end

local function hasLineOfSight(origin: Vector3, target: Vector3, excluded: { Instance }?): boolean
	lineOfSightParams.FilterDescendantsInstances = excluded or {}
	return workspace:Raycast(origin, target - origin, lineOfSightParams) == nil
end

--[=[
	@within RaycastUtils
	@param excluded { Instance }? -- extra instances to exclude (e.g. the thrower's character)
	@return { Instance } -- the exclusion list plus the map's `Wall_Collisions` folder when present

	Builds the exclusion filter for projectile casts: projectiles should hit the visible
	map geometry, not the invisible walls under `workspace.Map.Collisions.Wall_Collisions`.
]=]
local function projectileExclusions(excluded: { Instance }?): { Instance }
	local filter: { Instance } = if excluded then table.clone(excluded) else {}

	local wallCollisions = workspace.Map.Collisions:FindFirstChild("Wall_Collisions")
	if wallCollisions then
		table.insert(filter, wallCollisions)
	end

	return filter
end

--[=[
	@within RaycastUtils
	@param excluded { Instance }? -- extra instances to exclude (e.g. the caster, projectile containers)
	@return RaycastParams -- exclude-filtered params for projectile casts

	Builds RaycastParams for bullet/projectile casts: applies [RaycastUtils.projectileExclusions],
	respects CanCollide (decorative non-collidable props don't block shots), and casts in the
	"Bullet" collision group — the shared projectile filtering convention.
]=]
local function projectileParams(excluded: { Instance }?): RaycastParams
	local castParams = RaycastParams.new()
	castParams.FilterType = Enum.RaycastFilterType.Exclude
	castParams.RespectCanCollide = true
	castParams.CollisionGroup = "Bullet"
	castParams.FilterDescendantsInstances = projectileExclusions(excluded)

	return castParams
end

return {
	getPointOnGround = getPointOnGround,
	hasLineOfSight = hasLineOfSight,
	projectileExclusions = projectileExclusions,
	projectileParams = projectileParams,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsUtil = require(ReplicatedStorage.Shared.Modules.Utils.PhysicsUtil)
local TimeUtils = require(ReplicatedStorage.Shared.Modules.Utils.TimeUtils)

local allProjectiles = {}

local Projectiles = {} :: { InternalProjectile }

export type ProjectileData = {
	started: number,
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3,

	params: RaycastParams,
	size: Vector3,

	gravity: Vector3?,
	timeout: number?,

	onUpdate: ((InternalProjectile, Vector3, Vector3) -> ())?,
	onHit: ((InternalProjectile, RaycastResult) -> ())?,
	onDestroy: (() -> ())?,
}

type InternalProjectile = ProjectileData & {
	position: Vector3,
}

local function stepSingleProjectile(projectile: InternalProjectile)
	local origin = projectile.origin
	local gravity = projectile.gravity
	local velocity = projectile.velocity
	local deltaTime = TimeUtils.now() - projectile.started

	local nextPosition = PhysicsUtil.projectilePosition(origin, velocity, gravity, deltaTime)
	local projectileDirection = nextPosition - projectile.position
	local projectileDistance = projectileDirection.Magnitude

	-- No displacement this step (e.g. spawned this frame before the server clock advanced).
	-- A zero-length ray would feed NaN (zeroVector.Unit) to Blockcast and CFrame.lookAt would
	-- error on identical points, so skip the cast and wait until time has moved on.
	if projectileDistance < 1e-5 then
		if projectile.timeout and deltaTime > projectile.timeout then
			if projectile.onDestroy then
				projectile.onDestroy()
			end

			return true
		end

		return false
	end

	local projectileCFrame = CFrame.lookAt(projectile.position, nextPosition)

	local cast = workspace:Blockcast(
		projectileCFrame,
		projectile.size,
		projectileDirection.Unit * projectileDistance,
		projectile.params
	)
	if cast then
		local didHit = true

		if projectile.onHit then
			didHit = projectile.onHit(projectile, cast) ~= false
		end

		if didHit then
			if projectile.onDestroy then
				projectile.onDestroy()
			end

			return true
		end
	end

	if projectile.timeout and deltaTime > projectile.timeout then
		if projectile.onDestroy then
			projectile.onDestroy()
		end

		return true
	end

	if projectile.onUpdate then
		local pointAfter = PhysicsUtil.projectilePosition(origin, velocity, gravity, deltaTime + 1 / 60)
		local nextDirection = (pointAfter - nextPosition).Unit

		projectile.onUpdate(projectile, nextPosition, nextDirection)
	end

	projectile.position = nextPosition
	return false
end

function Projectiles.create(data: ProjectileData): InternalProjectile
	local deltaTime = TimeUtils.now() - data.started

	local gravity = data.gravity or Vector3.new(0, -workspace.Gravity, 0)
	local position = PhysicsUtil.projectilePosition(data.origin, data.velocity, gravity, deltaTime)

	local projectileData: InternalProjectile = {
		started = data.started,
		origin = data.origin,
		direction = data.direction,
		velocity = data.velocity,
		params = data.params,
		size = data.size,
		gravity = gravity,
		timeout = data.timeout,
		onUpdate = data.onUpdate,
		onHit = data.onHit,
		onDestroy = data.onDestroy,
		position = position,
	}

	for _ = 0, deltaTime, 1 / 60 do
		local canDestroy = stepSingleProjectile(projectileData)
		if canDestroy then
			return nil :: any
		end
	end

	table.insert(allProjectiles, projectileData)
	return projectileData
end

function Projectiles.step()
	for i = #allProjectiles, 1, -1 do
		local projectile = allProjectiles[i]
		if not projectile then
			continue
		end

		local canDestroy = stepSingleProjectile(projectile)
		if canDestroy then
			table.remove(allProjectiles, i)
		end
	end
end

RunService.Heartbeat:Connect(function()
	Projectiles.step()
end)

return Projectiles

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Shared.Modules.Promise)

local abs = math.abs
local inf = math.huge

export type BoundingBoxPredicate = (part: BasePart) -> boolean

local function getBoundingBox(model: Model, cb: BoundingBoxPredicate?): Region3
	local minX, minY, minZ = inf, inf, inf
	local maxX, maxY, maxZ = -inf, -inf, -inf

	for _, obj in model:GetDescendants() do
		if not obj:IsA("BasePart") then
			continue
		end

		if cb and not cb(obj) then
			continue
		end

		local cf = obj.CFrame
		local size = obj.Size
		local sx, sy, sz = size.X, size.Y, size.Z
		local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = cf:GetComponents()

		-- https://zeuxcg.org/2010/10/17/aabb-from-obb-with-component-wise-abs/
		local wsx = 0.5 * (abs(R00) * sx + abs(R01) * sy + abs(R02) * sz)
		local wsy = 0.5 * (abs(R10) * sx + abs(R11) * sy + abs(R12) * sz)
		local wsz = 0.5 * (abs(R20) * sx + abs(R21) * sy + abs(R22) * sz)

		if minX > x - wsx then
			minX = x - wsx
		end
		if minY > y - wsy then
			minY = y - wsy
		end
		if minZ > z - wsz then
			minZ = z - wsz
		end

		if maxX < x + wsx then
			maxX = x + wsx
		end
		if maxY < y + wsy then
			maxY = y + wsy
		end
		if maxZ < z + wsz then
			maxZ = z + wsz
		end
	end

	return Region3.new(Vector3.new(minX, minY, minZ), Vector3.new(maxX, maxY, maxZ))
end

local function findFirstChild(root: Instance, path: string): Instance?
	local current: Instance? = root

	for _, segment in string.split(path, "/") do
		current = current and current:FindFirstChild(segment)

		if not current then
			return nil
		end
	end

	return current
end

local function waitForChild<T>(root: Instance, path: string)
	return Promise.new(function(resolve, reject, onCancel)
		local obj: Instance = root

		local thread: thread? = nil
		local destroyed: RBXScriptConnection? = nil

		local function cancel()
			if destroyed then
				destroyed = destroyed:Disconnect()
				destroyed = nil
			end

			if thread then
				task.cancel(thread)
				thread = nil
			end
		end

		thread = task.spawn(function()
			for _, segment in string.split(path, "/") do
				destroyed = obj.Destroying:Once(function()
					cancel()
					reject("Instance was destroyed")
				end)

				obj = obj:WaitForChild(segment)

				if destroyed then
					destroyed:Disconnect()
					destroyed = nil
				end
			end

			thread = nil
			resolve(obj)
		end)

		onCancel(cancel)
	end) :: Promise.Promise<T & Instance>
end

local function getPlayerFromPart(part: BasePart): Player?
	local character = part.Parent
	if character then
		return Players:GetPlayerFromCharacter(character)
	end

	return nil
end

return {
	getBoundingBox = getBoundingBox,
	findFirstChild = findFirstChild,
	waitForChild = waitForChild,
	getPlayerFromPart = getPlayerFromPart,
}

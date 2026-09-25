local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)

local function createPart(props: { [string]: any }?): Part
	local debugPart = Create("Part", {
		Name = "DebugPart",
		Size = Vector3.new(1, 1, 1),
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 0.8,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 0, 0),
	}) :: Part

	if props then
		for key, value in props do
			(debugPart :: any)[key] = value
		end
	end

	return debugPart
end

local function visDirection(origin: Vector3, endPos: Vector3)
	local basePart = Instance.new("Part")

	basePart.Transparency = 0.8
	basePart.Material = Enum.Material.Neon
	basePart.Size = Vector3.new(0.2, 0.2, (origin - endPos).Magnitude)
	basePart.CFrame = CFrame.new(endPos, origin) * CFrame.new(0, 0, -basePart.Size.Z / 2)
	basePart.Anchored = true
	basePart.CanCollide = false
	basePart.CanTouch = false
	basePart.CanQuery = false
	basePart.CastShadow = false

	return basePart
end

return {
	createPart = createPart,
	visDirection = visDirection,
}

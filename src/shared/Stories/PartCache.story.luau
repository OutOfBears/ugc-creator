local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PartCache = require("../Modules/PartCache")
local UILabs = require(ReplicatedStorage.Packages.UILabs)

local RING_HEIGHT_SPAN = 6
local SPAWN_DISTANCE = 30

local controls = {
	cacheSize = UILabs.Number(50, 0, 500, 1),
	maxParts = UILabs.Slider(150, 1, 400, 1),
	radius = UILabs.Slider(20, 4, 60, 0.5),
	spinSpeed = UILabs.Slider(1, 0, 4, 0.1),
	cycleSpeed = UILabs.Slider(0.3, 0.05, 2, 0.05),
}

local function createTemplate(): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(85, 170, 255)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	return part
end

local function createStatsLabel(target: GuiObject): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextColor3 = Color3.fromRGB(235, 235, 235)
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = ""
	label.Parent = target

	return label
end

return UILabs.CreateGenericStory({
	name = "PartCache",
	summary = "Cycles a ring of pooled parts in and out: getPart claims parts as the count rises, returnPart"
		.. " parks them off-screen as it falls. Watch the free-pool count climb as parts go out.",
	controls = controls,
}, function(props)
	local initialSize = math.max(0, math.floor(props.controls.cacheSize))

	local template = createTemplate()
	local cache = PartCache.new(template, initialSize)
	cache:setExpandAmount(math.max(initialSize, 1))

	local label = createStatsLabel(props.target)

	local camera = workspace.CurrentCamera
	local center = if camera
		then camera.CFrame.Position + camera.CFrame.LookVector * SPAWN_DISTANCE
		else Vector3.yAxis * 20

	local active: { BasePart } = {}
	local elapsed = 0

	local connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt

		for _, part in active do
			cache:returnPart(part)
		end
		table.clear(active)

		local maxParts = math.floor(props.controls.maxParts)
		local radius = props.controls.radius
		local spin = elapsed * props.controls.spinSpeed
		local cycle = (1 - math.cos(elapsed * props.controls.cycleSpeed * 2 * math.pi)) / 2
		local count = math.floor(maxParts * cycle)

		for index = 1, count do
			local fraction = index / maxParts
			local angle = fraction * 2 * math.pi + spin
			local height = (fraction - 0.5) * RING_HEIGHT_SPAN
			local offset = Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)

			active[index] = cache:getPart(CFrame.new(center + offset))
		end

		local sample = if active[1] then tostring(cache:isInUse(active[1])) else "n/a"
		label.Text = string.format(
			"PartCache\nactive (in use): %d / %d\nfree pool: %d\ntotal clones: %d\npreallocated: %d\nactive[1] isInUse: %s",
			count,
			maxParts,
			#cache.freeObjects,
			#cache.cacheHolder:GetChildren(),
			cache.preallocatedAmount,
			sample
		)
	end)

	return function()
		connection:Disconnect()
		cache:destroy()
		template:Destroy()
		label:Destroy()
	end
end)

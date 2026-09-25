local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LightningBolt = require(ReplicatedStorage.Client.Modules.LightningBolt)
local UILabs = require(ReplicatedStorage.Packages.UILabs)

local function spawnBolt(controls: { [string]: any }): LightningBolt.LightningBolt
	local cf = workspace.CurrentCamera.CFrame
	local axis = cf.RightVector
	local center = cf.Position + cf.LookVector * (controls.length * 0.8 + 16)
	local a0 = { WorldPosition = center - axis * (controls.length / 2), WorldAxis = axis }
	local a1 = { WorldPosition = center + axis * (controls.length / 2), WorldAxis = axis }

	local bolt = LightningBolt.new(a0, a1, controls.partCount)
	bolt.thickness = controls.thickness
	bolt.maxRadius = controls.maxRadius
	bolt.frequency = controls.frequency
	bolt.animationSpeed = controls.animationSpeed
	bolt.pulseSpeed = controls.pulseSpeed
	bolt.color = controls.color

	return bolt
end

return UILabs.CreateGenericStory({
	summary = "Procedural lightning bolt spanning two points in front of the camera. "
		.. "Renders in the 3D viewport, not the preview pane.",
	controls = {
		length = UILabs.Slider(40, 5, 120, 1),
		partCount = UILabs.Slider(30, 2, 60, 1),
		thickness = UILabs.Slider(1, 0.1, 5, 0.1),
		maxRadius = UILabs.Slider(2.4, 0, 10, 0.1),
		frequency = UILabs.Slider(1, 0, 5, 0.1),
		animationSpeed = UILabs.Slider(7, 0, 30, 0.5),
		pulseSpeed = UILabs.Slider(2, 0.5, 10, 0.1),
		color = UILabs.Datatype.Color3(Color3.new(1, 1, 1)),
	},
}, function(props: UILabs.GenericProps)
	local bolt = spawnBolt(props.controls)

	local unsubscribe = props.subscribe(function(values)
		bolt:destroy()
		bolt = spawnBolt(values)
	end)

	return function()
		unsubscribe()
		bolt:destroy()
	end
end)

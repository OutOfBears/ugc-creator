local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LightningBolt = require(ReplicatedStorage.Client.Modules.LightningBolt)
local LightningSparks = require(ReplicatedStorage.Client.Modules.LightningBolt.LightningSparks)
local UILabs = require(ReplicatedStorage.Packages.UILabs)

local function spawn(controls: { [string]: any }): (LightningBolt.LightningBolt, LightningSparks.LightningSparks)
	local cf = workspace.CurrentCamera.CFrame
	local axis = cf.RightVector
	local center = cf.Position + cf.LookVector * (controls.length * 0.8 + 16)
	local a0 = { WorldPosition = center - axis * (controls.length / 2), WorldAxis = axis }
	local a1 = { WorldPosition = center + axis * (controls.length / 2), WorldAxis = axis }

	local bolt = LightningBolt.new(a0, a1, controls.partCount)
	bolt.thickness = controls.thickness
	bolt.color = controls.color

	local sparks = LightningSparks.new(bolt, controls.maxSparkCount)
	sparks.minDistance = math.min(controls.minDistance, controls.maxDistance)
	sparks.maxDistance = math.max(controls.minDistance, controls.maxDistance)

	return bolt, sparks
end

return UILabs.CreateGenericStory({
	summary = "Sparks crackling off a parent lightning bolt. Renders in the 3D viewport, not the preview pane.",
	controls = {
		length = UILabs.Slider(40, 5, 120, 1),
		partCount = UILabs.Slider(30, 2, 60, 1),
		thickness = UILabs.Slider(1.5, 0.1, 5, 0.1),
		maxSparkCount = UILabs.Slider(10, 1, 30, 1),
		minDistance = UILabs.Slider(3, 0.5, 15, 0.5),
		maxDistance = UILabs.Slider(6, 1, 25, 0.5),
		color = UILabs.Datatype.Color3(Color3.new(0.6, 0.8, 1)),
	},
}, function(props: UILabs.GenericProps)
	local bolt, sparks = spawn(props.controls)

	local unsubscribe = props.subscribe(function(values)
		sparks:destroy()
		bolt:destroy()
		bolt, sparks = spawn(values)
	end)

	return function()
		unsubscribe()
		sparks:destroy()
		bolt:destroy()
	end
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LightningExplosion = require(ReplicatedStorage.Client.Modules.LightningBolt.LightningExplosion)
local UILabs = require(ReplicatedStorage.Packages.UILabs)

return UILabs.CreateGenericStory({
	summary = "Lightning explosion bursts repeating in front of the camera. "
		.. "Renders in the 3D viewport, not the preview pane.",
	controls = {
		size = UILabs.Slider(1, 0.1, 1, 0.05),
		numBolts = UILabs.Slider(14, 1, 30, 1),
		interval = UILabs.Slider(1, 0.3, 5, 0.1),
		color = UILabs.Datatype.Color3(Color3.fromRGB(255, 40, 40)),
		boltColor = UILabs.Datatype.Color3(Color3.fromRGB(80, 80, 255)),
	},
}, function(props: UILabs.GenericProps)
	local current = props.controls
	local running = true
	local active: LightningExplosion.LightningExplosion? = nil

	local unsubscribe = props.subscribe(function(values)
		current = values
	end)

	task.spawn(function()
		while running do
			local cf = workspace.CurrentCamera.CFrame
			active = LightningExplosion.new(
				cf.Position + cf.LookVector * 40,
				current.size,
				current.numBolts,
				current.color,
				current.boltColor
			)
			task.wait(current.interval)
		end
	end)

	return function()
		running = false
		unsubscribe()
		if active then
			active:destroy()
		end
	end
end)

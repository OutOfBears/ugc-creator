local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Behaviors = require(ReplicatedStorage.Shared.Modules.Utils.Behaviors)
local Network = require(ReplicatedStorage.Shared.Modules.Network).server()
local Types = require(ReplicatedStorage.Shared.Types)

local BehaviorsService = {} :: Types.Service

function BehaviorsService.onInit()
	for _, behavior in script.Parent.Parent.Behaviors:GetChildren() do
		if behavior:IsA("ModuleScript") then
			require(behavior)
		end
	end
end

function BehaviorsService.onRun()
	Network.on("execute", function(player: Player, object: Instance, tag: string, method: string, ...)
		local behaviors = Behaviors.getBehaviorsWithTag(object, tag)

		for _, behavior in behaviors do
			local executables = behavior.executables

			if executables and executables[method] then
				executables[method](player, ...)
			end
		end
	end)
end

return BehaviorsService

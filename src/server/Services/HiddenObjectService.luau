local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Observers = require(ReplicatedStorage.Packages.Observers)
local Types = require(ReplicatedStorage.Shared.Types)

local HiddenObjectService = {} :: Types.Service

function HiddenObjectService.onRun()
	Observers.observeTag("Hidden", function(object)
		local cache = {}

		if object:IsA("BasePart") then
			cache[object] = object.Transparency
			object.Transparency = 1
		end

		for _, descendant in object:GetDescendants() do
			if descendant:IsA("BasePart") then
				cache[descendant] = descendant.Transparency
				descendant.Transparency = 1
			end
		end

		return function()
			for obj, transparency in cache do
				obj.Transparency = transparency
			end
		end
	end, { workspace })
end

return HiddenObjectService

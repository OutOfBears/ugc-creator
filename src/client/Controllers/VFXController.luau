local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ForgeVFX = require(ReplicatedStorage.Packages.ForgeVFX)
local Types = require(ReplicatedStorage.Shared.Types)

local VFXController = {} :: Types.Controller

function VFXController.onInit()
	ForgeVFX.init()
end

return VFXController

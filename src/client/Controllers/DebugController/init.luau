local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Iris = require(ReplicatedStorage.Shared.Modules.Iris)
local IrisConfig = require(script.IrisConfig)
local Types = require(ReplicatedStorage.Shared.Types)

local IS_STUDIO = RunService:IsStudio()

local DebugController = {} :: Types.Controller

function DebugController.onRun()
	if not IS_STUDIO then
		return
	end

	Iris.UpdateGlobalConfig(IrisConfig)
	Iris.Init()
end

return DebugController

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClientAtoms = require(ReplicatedStorage.Client.Modules.ClientAtoms)
local Types = require(ReplicatedStorage.Shared.Types)

local viewportConnection: RBXScriptConnection? = nil

local ViewportController = {} :: Types.Controller

function ViewportController.onInit()
	local function trackCamera(camera: Camera?)
		if viewportConnection then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end

		if not camera then
			return
		end

		ClientAtoms.viewportSize(camera.ViewportSize)
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			ClientAtoms.viewportSize(camera.ViewportSize)
		end)
	end

	trackCamera(Workspace.CurrentCamera)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		trackCamera(Workspace.CurrentCamera)
	end)
end

return ViewportController

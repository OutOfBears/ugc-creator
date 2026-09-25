local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Konsole = require(ReplicatedStorage.Packages.Konsole)
local Types = require(ReplicatedStorage.Shared.Types)

local KonsoleController = {} :: Types.Controller & {}

local client: any = nil

function KonsoleController.onRun()
	local clientCommands = ReplicatedStorage:WaitForChild("KonsoleClientCommands")
	for _, command in clientCommands:GetChildren() do
		if command:IsA("ModuleScript") then
			Konsole.define(require(command) :: Konsole.Definition)
		end
	end

	client = Konsole.create({
		input = {
			activationKeys = { Enum.KeyCode.Backquote, Enum.KeyCode.F2 },
			forceclose = true, -- outside click fully closes instead of only releasing input focus
		},
	})

	client:setSuggestions(Konsole.Kommand.suggestions())
	client:setSchemas(Konsole.Kommand.schemas())
	client:bindRun(function(text)
		return Konsole.Dispatch.execute(text)
	end)

	Konsole.Kommand.watch(function()
		client:setSuggestions(Konsole.Kommand.suggestions())
		client:setSchemas(Konsole.Kommand.schemas())
	end)
end

return KonsoleController

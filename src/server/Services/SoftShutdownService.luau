local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Types = require(ReplicatedStorage.Shared.Types)

local SoftShutdownService = {} :: Types.Service

local function teleport(players: { Player })
	while not pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players)
	end) do
		task.wait(1)
	end
end

function SoftShutdownService.onInit()
	TeleportService.TeleportInitFailed:Connect(function(player: Player)
		if player.Parent then
			teleport({ player })
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() or #Players:GetPlayers() == 0 then
			return
		end

		workspace:SetAttribute("Shutdown", true)

		task.wait(1)
		local added = Players.PlayerAdded:Connect(function(player: Player)
			teleport({ player })
		end)

		teleport(Players:GetPlayers())

		while #Players:GetPlayers() > 0 do
			task.wait(0.5)
		end

		added:Disconnect()
	end)
end

return SoftShutdownService

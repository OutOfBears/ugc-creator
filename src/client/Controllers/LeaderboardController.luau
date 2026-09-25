local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

--[=[
	@class LeaderboardController
	@client

	Renders the in-world leaderboard boards. Each Workspace model tagged `Leaderboard` is named
	after the metric it displays; mount a board onto that model's SurfaceGui here, fed by the
	cross-server board for that metric from [LeaderboardReplicator].
]=]
local LeaderboardController = {} :: Types.Controller

function LeaderboardController.onRun() end

return LeaderboardController

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttributeReplicator = require(ReplicatedStorage.Shared.Modules.AttributeReplicator)
local LeaderboardConfig = require("../Data/LeaderboardConfig")

export type Metric = LeaderboardConfig.Metric
export type PeriodType = LeaderboardConfig.PeriodType
export type Row = { rank: number, name: string, score: number, userId: number }
export type Board = { Row }

local FOLDER_NAME = "Leaderboard"

local defaults = {
	nextRefreshAt = nil :: number?,
}

local folder = Instance.new("Folder")
folder.Name = FOLDER_NAME
folder.Parent = ReplicatedStorage.Replicators

local replicator = AttributeReplicator.new(folder, defaults)

--[=[
	@class LeaderboardReplicator
	@server

	Owns the single global leaderboard replicator, an [AttributeReplicator] on a `Leaderboard`
	folder under `ReplicatedStorage.Replicators`. `LeaderboardService` publishes each ranked board
	through this typed surface (keyed `"<metric>_<period>"` — attribute names can't contain colons);
	clients read it with the `useLeaderboard` hook. The next refresh time is published as an absolute
	timestamp (`nextRefreshAt`), so clients derive the countdown locally rather than the server
	ticking it.
]=]
local LeaderboardReplicator = {}

--[=[
	@within LeaderboardReplicator
	@param metric Metric -- the board's stat (kills / wins / streak)
	@param periodType PeriodType -- the board's period (day / week)
	@param rows Board -- the ranked rows, highest score first
]=]
function LeaderboardReplicator.setBoard(metric: Metric, periodType: PeriodType, rows: Board)
	replicator:Set(`{metric}_{periodType}`, rows)
end

--[=[
	@within LeaderboardReplicator
	@param timestamp number -- absolute UTC time (os.time) at which the boards next refresh
]=]
function LeaderboardReplicator.setNextRefreshAt(timestamp: number)
	replicator:Set("nextRefreshAt", timestamp)
end

return LeaderboardReplicator

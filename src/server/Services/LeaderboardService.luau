local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Types = require(ReplicatedStorage.Shared.Types)

local LeaderboardConfig = require("../Data/LeaderboardConfig")
local LeaderboardReplicator = require("../Modules/LeaderboardReplicator")
local LeaderboardStore = require("../Modules/LeaderboardStore")

type Metric = LeaderboardConfig.Metric
type PeriodType = LeaderboardConfig.PeriodType
type Bucket = { [string]: { [number]: number } }

--[=[
	@class LeaderboardService
	@server

	Records metric deltas into the cross-server global leaderboards. Deltas are accumulated in
	memory bucketed by the target store name (computed at record time so they land in the correct
	UTC day/week even across a midnight flush), flushed to OrderedDataStores in batches, and the
	top-N of each board is read back on a staggered round-robin and published through
	[LeaderboardReplicator]. Each metric aggregates over its period as configured in
	[LeaderboardConfig] — `sum` accumulates, `max` keeps the period best.
]=]
local LeaderboardService = {} :: Types.Service

local maid = Maid.new()

local pendingSum: Bucket = {}
local pendingMax: Bucket = {}
local nameCache: { [number]: string } = {}
local boardOrder: { { metric: Metric, periodType: PeriodType } } = {}
local flushing = false

local function _accumulate(bucket: Bucket, storeName: string, userId: number, value: number, keepMax: boolean)
	local users = bucket[storeName]
	if not users then
		users = {}
		bucket[storeName] = users
	end

	if keepMax then
		users[userId] = math.max(users[userId] or 0, value)
	else
		users[userId] = (users[userId] or 0) + value
	end
end

local function collectWork(
	bucket: Bucket,
	onlyUserId: number?
): { { storeName: string, userId: number, value: number } }
	local work = {}
	for storeName, users in bucket do
		for userId, value in users do
			if not onlyUserId or userId == onlyUserId then
				table.insert(work, { storeName = storeName, userId = userId, value = value })
			end
		end
	end
	return work
end

local function clearCommitted(
	bucket: Bucket,
	storeName: string,
	userId: number,
	committedValue: number,
	keepMax: boolean
)
	local users = bucket[storeName]
	if not users then
		return
	end

	if keepMax then
		if (users[userId] or 0) <= committedValue then
			users[userId] = nil
		end
	else
		local remaining = (users[userId] or 0) - committedValue
		if remaining <= 0 then
			users[userId] = nil
		else
			users[userId] = remaining
		end
	end

	if next(users) == nil then
		bucket[storeName] = nil
	end
end

local function flush(onlyUserId: number?)
	while flushing do
		task.wait()
	end
	flushing = true

	local ok, err = pcall(function()
		for _, work in collectWork(pendingSum, onlyUserId) do
			if LeaderboardStore.commitDelta(work.storeName, work.userId, work.value) then
				clearCommitted(pendingSum, work.storeName, work.userId, work.value, false)
			end
		end

		for _, work in collectWork(pendingMax, onlyUserId) do
			if LeaderboardStore.commitMax(work.storeName, work.userId, work.value) then
				clearCommitted(pendingMax, work.storeName, work.userId, work.value, true)
			end
		end
	end)

	flushing = false
	if not ok then
		warn(`[LeaderboardService] flush failed: {err}`)
	end
end

local function resolveName(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end

	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and name then
		nameCache[userId] = name
		return name
	end

	return `Player{userId}`
end

local function publishOne(metric: Metric, periodType: PeriodType)
	local index = LeaderboardStore.periodIndex(periodType, os.time())
	local entries =
		LeaderboardStore.fetchTop(LeaderboardStore.storeName(metric, periodType, index), LeaderboardConfig.topN)
	if not entries then
		return
	end

	local rows: LeaderboardReplicator.Board = {}
	for rank, entry in entries do
		table.insert(rows, {
			rank = rank,
			userId = entry.userId,
			score = entry.score,
			name = resolveName(entry.userId),
		})
	end

	LeaderboardReplicator.setBoard(metric, periodType, rows)
end

function LeaderboardService.onRun()
	for metric in LeaderboardConfig.metrics do
		for _, periodType in LeaderboardConfig.periods do
			table.insert(boardOrder, { metric = metric, periodType = periodType })
		end
	end

	maid:giveTask(Players.PlayerRemoving:Connect(function(player: Player)
		task.spawn(flush, player.UserId)
	end))
	game:BindToClose(function()
		flush()
	end)

	if not LeaderboardStore.isEnabled() then
		return
	end

	task.spawn(function()
		task.wait(math.random() * LeaderboardConfig.flushSeconds)
		while true do
			flush()
			task.wait(LeaderboardConfig.flushSeconds)
		end
	end)

	task.spawn(function()
		task.wait(math.random() * LeaderboardConfig.publishStaggerSeconds)

		local cursor = 0
		while true do
			cursor = cursor % #boardOrder + 1

			local board = boardOrder[cursor]
			if not board then
				task.wait(LeaderboardConfig.publishStaggerSeconds)
				continue
			end

			publishOne(board.metric, board.periodType)
			LeaderboardReplicator.setNextRefreshAt(os.time() + LeaderboardConfig.publishStaggerSeconds)

			task.wait(LeaderboardConfig.publishStaggerSeconds)
		end
	end)
end

return LeaderboardService

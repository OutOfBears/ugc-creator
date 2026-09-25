local DataStoreService = game:GetService("DataStoreService")

local LeaderboardConfig = require("../Data/LeaderboardConfig")

export type Metric = LeaderboardConfig.Metric
export type PeriodType = LeaderboardConfig.PeriodType
export type Entry = { userId: number, score: number }

local BUDGET_WAIT_ATTEMPTS = 10

local enabled: boolean? = nil

--[=[
	@class LeaderboardStore
	@server

	Stateless wrapper over the cross-server OrderedDataStores that back the global leaderboards.
	One store exists per `(metric, periodType, periodIndex)` with the index embedded in the store
	name, so a day/week rollover simply targets a fresh empty store — no cleanup job. Every call is
	pcall-guarded with bounded backoff and yields for request budget before bursting, and all writes
	go through `UpdateAsync` so concurrent servers aggregate atomically.
]=]
local LeaderboardStore = {}

local function withRetry<T>(requestType: Enum.DataStoreRequestType, fn: () -> T): (boolean, T?)
	for attempt = 1, LeaderboardConfig.retry.attempts do
		local waited = 0
		while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 and waited < BUDGET_WAIT_ATTEMPTS do
			task.wait(1)
			waited += 1
		end

		local ok, result = pcall(fn)
		if ok then
			return true, result
		end

		if attempt < LeaderboardConfig.retry.attempts then
			task.wait(LeaderboardConfig.retry.baseDelay * 2 ^ (attempt - 1))
		end
	end

	return false, nil
end

--[=[
	@within LeaderboardStore
	@param periodType PeriodType -- "day" or "week"
	@param now number -- UTC unix seconds (os.time()) at record time
	@return number -- the integer index of the period `now` falls in
]=]
function LeaderboardStore.periodIndex(periodType: PeriodType, now: number): number
	if periodType == "week" then
		return math.floor((now - LeaderboardConfig.weekOffsetSeconds) / LeaderboardConfig.weekSeconds)
	end
	return math.floor(now / LeaderboardConfig.daySeconds)
end

--[=[
	@within LeaderboardStore
	@param metric Metric -- the tracked stat
	@param periodType PeriodType -- "day" or "week"
	@param index number -- the period index from [LeaderboardStore.periodIndex]
	@return string -- the OrderedDataStore name, e.g. "LB:v1:kills:day:20299"
]=]
function LeaderboardStore.storeName(metric: Metric, periodType: PeriodType, index: number): string
	return `{LeaderboardConfig.storePrefix}:{LeaderboardConfig.schemaVersion}:{metric}:{periodType}:{index}`
end

--[=[
	@within LeaderboardStore

	Probes once (memoized) whether DataStores are reachable. Returns false in a Studio session
	without "Studio Access to API Services", letting callers skip the leaderboard loops entirely.

	@return boolean -- true when DataStore requests are permitted
]=]
function LeaderboardStore.isEnabled(): boolean
	if enabled == nil then
		local store = DataStoreService:GetDataStore(`{LeaderboardConfig.storePrefix}:probe`)
		enabled = (pcall(function()
			store:GetAsync("probe")
		end))
	end
	return enabled :: boolean
end

--[=[
	@within LeaderboardStore

	Atomically adds `delta` to a player's score in a SUM board (kills, wins).

	@param storeName string -- the target store from [LeaderboardStore.storeName]
	@param userId number -- the player's UserId
	@param delta number -- the amount to add
	@return boolean -- true if the write committed
]=]
function LeaderboardStore.commitDelta(storeName: string, userId: number, delta: number): boolean
	if delta == 0 then
		return true
	end

	local store = DataStoreService:GetOrderedDataStore(storeName)
	local ok = withRetry(Enum.DataStoreRequestType.UpdateAsync, function()
		store:UpdateAsync(tostring(userId), function(old: number?)
			return (old or 0) + delta
		end)
	end)
	return ok
end

--[=[
	@within LeaderboardStore

	Atomically raises a player's score to `value` in a MAX board (streak), leaving it unchanged
	when the stored value is already higher.

	@param storeName string -- the target store from [LeaderboardStore.storeName]
	@param userId number -- the player's UserId
	@param value number -- the candidate value
	@return boolean -- true if the write committed
]=]
function LeaderboardStore.commitMax(storeName: string, userId: number, value: number): boolean
	local store = DataStoreService:GetOrderedDataStore(storeName)
	local ok = withRetry(Enum.DataStoreRequestType.UpdateAsync, function()
		store:UpdateAsync(tostring(userId), function(old: number?)
			return math.max(old or 0, value)
		end)
	end)
	return ok
end

--[=[
	@within LeaderboardStore

	Reads the top `topN` entries of a board, highest score first.

	@param storeName string -- the target store from [LeaderboardStore.storeName]
	@param topN number -- how many entries to return
	@return { Entry }? -- ranked entries, or nil if the read failed
]=]
function LeaderboardStore.fetchTop(storeName: string, topN: number): { Entry }?
	local store = DataStoreService:GetOrderedDataStore(storeName)
	local ok, pages = withRetry(Enum.DataStoreRequestType.GetSortedAsync, function()
		return store:GetSortedAsync(false, topN)
	end)
	if not ok or not pages then
		return nil
	end

	local entries = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(entries, { userId = userId, score = entry.value })
		end
	end
	return entries
end

return LeaderboardStore

export type Metric = string
export type PeriodType = "day" | "week"
export type MetricAgg = "sum" | "max"

export type LeaderboardConfig = {
	schemaVersion: string,
	storePrefix: string,
	metrics: { [Metric]: MetricAgg },
	periods: { PeriodType },
	daySeconds: number,
	weekSeconds: number,
	weekOffsetSeconds: number,
	topN: number,
	flushSeconds: number,
	publishStaggerSeconds: number,
	retry: {
		attempts: number,
		baseDelay: number,
	},
}

--[=[
	@class LeaderboardConfig
	@server

	Static tuning for the cross-server global leaderboards. `metrics` maps each tracked stat to
	how it aggregates over a period (`sum` accumulates, `max` keeps the period best) — it ships
	empty; add your metrics to turn the leaderboards on. `periods` lists the buckets each stat is
	recorded into. `flushSeconds`/`publishStaggerSeconds` pace the batched OrderedDataStore writes
	and the round-robin top-N reads so a busy server stays well under DataStore budgets.
	`weekOffsetSeconds` shifts the UTC week boundary to Monday 00:00.
]=]
local config: LeaderboardConfig = {
	schemaVersion = "v1",
	storePrefix = "LB",

	metrics = {},
	periods = { "day", "week" },

	daySeconds = 86400,
	weekSeconds = 604800,
	weekOffsetSeconds = 345600,
	topN = 25,

	flushSeconds = 30,
	publishStaggerSeconds = 15,

	retry = {
		attempts = 4,
		baseDelay = 1,
	},
}

table.freeze(config.metrics)
table.freeze(config.periods)
table.freeze(config.retry)
table.freeze(config)
return config

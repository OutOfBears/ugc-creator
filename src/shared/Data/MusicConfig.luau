export type MusicConfig = {
	fadeSeconds: number,
	fallbackLength: number,
	volume: number,
}

--[=[
	@class MusicConfig

	Tuning for the synced background music. `fadeSeconds` is the per-track fade-in the client
	applies on each switch; `fallbackLength` is how long the server holds a track whose asset
	length it couldn't resolve, so a bad id can't spin the playlist.
]=]
local config: MusicConfig = {
	fadeSeconds = 2,
	fallbackLength = 30,
	volume = 0.225,
}

table.freeze(config)

return config

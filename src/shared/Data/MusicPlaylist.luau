export type MusicPlaylist = { string | number }

--[=[
	@class MusicPlaylist

	The background music tracks the `MusicController` shuffles through, as `rbxassetid://`
	strings. Order here is irrelevant — the controller reshuffles on every pass. Replace these
	placeholders with the real track assets.
]=]
local playlist: MusicPlaylist = {
	1845756489,
	1848354536,
	1841647093,
	140722099430139,
}

table.freeze(playlist)

return playlist

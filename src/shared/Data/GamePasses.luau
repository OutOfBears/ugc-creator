export type GamePasses = {}

--[=[
	@class GamePasses

	Robux gamepass ids, keyed by the semantic name gameplay code reads. Every id is sourced
	from the generated [Products] table so [products.toml](products.toml) stays the single
	source of truth — do not hardcode ids here. An id of `0` means the pass has no product yet:
	the server treats it as unowned ([GamePassService] skips id `0`) and the shop leaves its buy
	button inert until `rbx-products sync` fills the real id.
]=]
local GamePasses: GamePasses = {}

table.freeze(GamePasses)

return GamePasses

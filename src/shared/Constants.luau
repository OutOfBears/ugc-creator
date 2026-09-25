local Constants = {
	IS_PROD = game.GameId == 0,
	GROUP_ID = 0,
	GROUP_RANKS = {} :: { [string]: number },
	SUPER_USERS = {} :: { [number]: boolean },
}

table.freeze(Constants)

return Constants

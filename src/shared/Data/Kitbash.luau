export type KitbashPiece = {
	name: string,
	thumbnail: string,
	minScale: number?,
	maxScale: number?,
}

export type Kitbash = { KitbashPiece }

--[=[
	@class Kitbash

	The decorative pieces a player can stick onto a creation, in picker order. Each `name` must
	match a MeshPart under `ReplicatedStorage.Assets.KitbashPieces`. A piece without `minScale` or
	`maxScale` falls back to the defaults in `CreationConfig`.
]=]
local kitbash: Kitbash = {
	{
		name = "GooglyEye",
		thumbnail = "rbxthumb://type=Asset&id=82309817363385&w=420&h=420",
	},
	{
		name = "GooglyEyeAltPupil",
		thumbnail = "rbxthumb://type=Asset&id=128081877892766&w=420&h=420",
	},
	{
		name = "Button",
		thumbnail = "rbxthumb://type=Asset&id=100727682923359&w=420&h=420",
		minScale = 1,
		maxScale = 4,
	},
	{
		name = "Spike",
		thumbnail = "rbxthumb://type=Asset&id=73708733249009&w=420&h=420",
		minScale = 1,
		maxScale = 3,
	},
	{
		name = "RedGemstone",
		thumbnail = "rbxthumb://type=Asset&id=88619907280627&w=420&h=420",
	},
	{
		name = "GoldGemstone",
		thumbnail = "rbxthumb://type=Asset&id=103358142562282&w=420&h=420",
	},
	{
		name = "PurpleGemstone",
		thumbnail = "rbxthumb://type=Asset&id=92018277988825&w=420&h=420",
		maxScale = 4,
	},
	{
		name = "GreenGemstone",
		thumbnail = "rbxthumb://type=Asset&id=137530316400711&w=420&h=420",
	},
}

table.freeze(kitbash)

return kitbash

export type BrushTip = {
	name: string,
	hardness: number,
	spacing: number,
}

export type BrushTips = {
	tips: { [string]: BrushTip },
	defaultTipId: string,
	stampResolution: number,
}

--[=[
	@class BrushTips

	The brush tip shapes every paint brush stamps with, keyed by tip id (the id travels in brush
	actions, so it is never renamed). `hardness` is the fraction of the radius painted at full
	strength before the edge fades out (1 is a hard edge that is still anti-aliased); `spacing` is
	the gap between canvas-brush stamps as a fraction of the brush diameter. Tips are rasterized at
	`stampResolution` pixels, the size the 3D brush projects from.
]=]
local brushTips: BrushTips = {
	tips = {
		SoftRound = {
			name = "Soft Round",
			hardness = 0.75,
			spacing = 0.1,
		},
	},

	defaultTipId = "SoftRound",
	stampResolution = 256,
}

table.freeze(brushTips.tips)
table.freeze(brushTips)

return brushTips

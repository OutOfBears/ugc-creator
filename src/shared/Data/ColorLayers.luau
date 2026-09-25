export type Layer = {
	name: string,
	textureId: string,
}

export type VariantOption = {
	name: string,
	textureId: string,
}

export type VariantGroup = {
	name: string,
	options: { VariantOption },
}

export type Catalog = {
	sortOrder: { string },
	layers: { Layer },
	variantGroups: { VariantGroup },
}

export type ColorLayers = { [string]: Catalog }

-- These are `rbxtemp://` ids from the authoring Studio session: they resolve only inside that
-- session and must be swapped for uploaded `rbxassetid://` ids (exported via region-exporter) before
-- this catalog works in a live game.
local catalogs: ColorLayers = {
	Fox = {
		sortOrder = {
			"Underbelly",
			"Head",
			"EyeGlare",
			"Right Eyebrow",
			"Nose",
			"Right Eye",
			"White Eyes",
			"Left Eye",
			"Black Outlines",
			"Headspots",
			"Left Eyebrow",
		},

		layers = {
			{ name = "Left Eye", textureId = "rbxtemp://267" },
			{ name = "Right Eye", textureId = "rbxtemp://273" },
			{ name = "Head", textureId = "rbxtemp://265" },
			{ name = "Black Outlines", textureId = "rbxtemp://263" },
			{ name = "White Eyes", textureId = "rbxtemp://276" },
			{ name = "Right Eyebrow", textureId = "rbxtemp://274" },
			{ name = "Left Eyebrow", textureId = "rbxtemp://268" },
			{ name = "Underbelly", textureId = "rbxtemp://275" },
			{ name = "Nose", textureId = "rbxtemp://272" },
			{ name = "EyeGlare", textureId = "rbxtemp://264" },
			{ name = "Headspots", textureId = "rbxtemp://266" },
		},

		variantGroups = {
			{
				name = "Mouth",
				options = {
					{ name = "Mouth1", textureId = "rbxtemp://269" },
					{ name = "Mouth2", textureId = "rbxtemp://270" },
					{ name = "Mouth3", textureId = "rbxtemp://271" },
				},
			},
		},
	},
}

table.freeze(catalogs)

return catalogs

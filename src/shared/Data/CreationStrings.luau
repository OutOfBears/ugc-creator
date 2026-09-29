export type CreationStrings = {
	robuxIcon: string,
	publishButton: string,

	failedToCreateImage: string,
	fixMeshImageSettings: string,

	resetEditsTitle: string,
	resetEditsBody: string,
	editorSwitchTitle: string,
	editorSwitchBody: string,
	accessoryAdjustmentTitle: string,
	accessoryAdjustmentBody: string,

	reflectivityToggle: string,
	uvWireframeToggle: string,
	uvCanvasResetView: string,

	layersPanelTitle: string,
	layerNameFormat: string,
	layerCountFormat: string,
	addLayer: string,
	blendModeLabel: string,
	layerMoveUp: string,
	layerMoveDown: string,
	layerOutOfMemory: string,
	layerHiddenPaint: string,

	counters: { sticker: string, kitbash: string },

	panelTitles: {
		brush: string,
		eraser: string,
		recolor: string,
		layerColor: string,
		stickers: string,
		pattern: string,
		kitbash: string,
		accessories: string,
	},
	toolTitles: {
		brushSize: string,
		color: string,
		padding: string,
		pattern: string,
		sections: string,
	},
}

--[=[
	@class CreationStrings

	User-facing copy for the item creation editor. `failedToCreateImage` is matched against the
	error text `AssetService` raises when it runs out of editable-image budget, which is how
	[CreationController] knows to retry a rung further down [CreationConfig].`textureResolutionSteps`
	— changing it breaks that retry.
]=]
local strings: CreationStrings = {
	robuxIcon = utf8.char(0xE002),
	publishButton = "Publish",

	failedToCreateImage = "Failed to create editable image.",
	fixMeshImageSettings = "Go to the Security Tab in Game Settings to enable this API.",

	resetEditsTitle = "Reset all edits?",
	resetEditsBody = "This will remove all edits you made to your asset.",
	editorSwitchTitle = "Are you sure?",
	editorSwitchBody = "If you start a new creation, your changes won't be saved.",
	accessoryAdjustmentTitle = "Accessory Fit May Vary",
	accessoryAdjustmentBody = "The accessory may not fit perfectly in the preview. You can adjust the fit using the Accessory Adjustment tool after purchase.",

	reflectivityToggle = "Reflective Effect",
	uvWireframeToggle = "UV Lines",
	uvCanvasResetView = "Fit",

	layersPanelTitle = "Layers",
	layerNameFormat = "Layer %d",
	layerCountFormat = "%d of %d layers",
	addLayer = "+ Add",
	blendModeLabel = "Blend Mode",
	layerMoveUp = "↑",
	layerMoveDown = "↓",
	layerOutOfMemory = "Not enough memory for another layer.",
	layerHiddenPaint = "This layer is hidden. Show it to paint on it.",

	counters = {
		sticker = "Stickers Applied",
		kitbash = "Add-Ons Applied",
	},

	panelTitles = {
		brush = "Paintbrush",
		eraser = "Eraser",
		recolor = "Recolor",
		layerColor = "Colors",
		stickers = "Stickers",
		pattern = "Pattern",
		kitbash = "Add-Ons",
		accessories = "Accessories",
	},
	toolTitles = {
		brushSize = "Brush Size",
		color = "Color",
		padding = "Padding",
		pattern = "Pattern",
		sections = "Sections",
	},
}

table.freeze(strings)

return strings

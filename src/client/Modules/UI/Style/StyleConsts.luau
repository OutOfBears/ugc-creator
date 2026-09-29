local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StyleLayouts = require(ReplicatedStorage.Shared.Data.StyleLayouts)

export type ColorPickerColor = {
	h: number,
	s: number,
	v: number,
}

export type StyleConsts = {
	tags: { [string]: string },
	regionOrdering: { [string]: number },
	modelDisplayName: { [string]: string },
	mobileWidthCutoff: number,
	defaultColorPickerColor: ColorPickerColor,
}

--[=[
	@class StyleConsts
	@client

	Structural constants for the UI style system. `tags` is the closed set of ids a component may be
	tagged with; [StyleRules] selects on those exact strings, so a tag value can never be reworded.
	Design tokens live in [StyleTokens] and image ids in [CreationIcons].
]=]
local StyleConsts: StyleConsts = {
	tags = {
		BaseUI = "BaseUI",
		UIParent = "UIParent",
		MediumIconButton = "MediumIconButton",
		ButtonSelected = "ButtonSelected",
		Hidden = "Hidden",
		CoreUIWithOpenPanel = "CoreUIWithOpenPanel",
		BuyButton = "BuyButton",

		Panel = "Panel",
		PanelHeader = "PanelHeader",
		PanelToolsContainer = "PanelToolsContainer",
		ToolFrame = "ToolFrame",
		ToolTitle = "ToolTitle",
		PanelParent = "PanelParent",

		HorizontalPillbar = "HorizontalPillbar",
		PillbarButton = "PillbarButton",
		LargePillbarButton = "LargePillbarButton",
		SmallPillbarButton = "SmallPillbarButton",

		ColorPicker = "ColorPicker",
		SatValPicker = "SatValPicker",
		SatGradient = "SatGradient",
		ValGradient = "ValGradient",
		HuePicker = "HuePicker",
		ColorDot = "ColorDot",
		OpacityPicker = "OpacityPicker",
		OpacityOverlay = "OpacityOverlay",
		OpacityGradient = "OpacityGradient",

		ToggleFrame = "ToggleFrame",
		TogglePill = "TogglePill",
		ToggleLabel = "ToggleLabel",
		ToggleFrameLeft = "ToggleFrameLeft",

		LocalMenu = "LocalMenu",
		LocalMenuConsole = "LocalMenuConsole",
		LocalMenuButton = "LocalMenuButton",
		LocalMenuButtonGroup = "LocalMenuButtonGroup",

		Toolbar = "Toolbar",
		Divider = "Divider",
		ToolbarButton = "ToolbarButton",
		ToolbarButtonGroup = "ToolbarButtonGroup",
		ToolbarParent = "ToolbarParent",

		SliderFrame = "SliderFrame",
		SliderBar = "SliderBar",
		SliderInput = "SliderInput",
		SliderHandle = "SliderHandle",

		BaseTile = "BaseTile",
		BaseTileButton = "BaseTileButton",
		TileGrid = "TileGrid",
		ScrollFrame = "ScrollFrame",

		MainHandle = "MainHandle",
		SmallHandle = "SmallHandle",

		ModalFrame = "ModalFrame",
		ModalTextFrame = "ModalTextFrame",
		ModalTitle = "ModalTitle",
		ModalBody = "ModalBody",
		ButtonFrame = "ButtonFrame",

		DefaultButton = "DefaultButton",
		EmphasisButton = "EmphasisButton",

		Overlay = "Overlay",

		SegmentedControl = "SegmentedControl",
		SegmentedControlButton = "SegmentedControlButton",
		AvatarPreviewSwitcher = "AvatarPreviewSwitcher",
		PreviewUIParent = "PreviewUIParent",

		ProgressBarFrame = "ProgressBarFrame",
		ProgressBarLabel = "ProgressBarLabel",
		ProgressBarBackground = "ProgressBarBackground",
		ProgressBarProgress = "ProgressBarProgress",

		MiniBaseTile = "MiniBaseTile",
		MiniBaseTileGroup = "MiniBaseTileGroup",
		MiniBaseTileSelected = "MiniBaseTileSelected",

		ItemSelectorFrame = "ItemSelectorFrame",
		ItemSelectorScrollFrame = "ItemSelectorScrollFrame",
		ItemSelectorFlexFrame = "ItemSelectorFlexFrame",

		CounterFrame = "CounterFrame",
		CounterLabel = "CounterLabel",

		UVCanvasContainer = "UVCanvasContainer",
		UVCanvasHeader = "UVCanvasHeader",
		UVCanvasHeaderButton = "UVCanvasHeaderButton",
		UVCanvasResizeGrip = "UVCanvasResizeGrip",
		UVCanvas = "UVCanvas",
		UVCanvasCursor = "UVCanvasCursor",

		SelectableList = "SelectableList",
		SelectableRow = "SelectableRow",
		SelectableRowLabel = "SelectableRowLabel",

		LayerIconButton = "LayerIconButton",
		LayerAddButton = "LayerAddButton",

		SegmentedControlFill = "SegmentedControlFill",
	},

	regionOrdering = {
		RobotModel = 1,
		TShirtModel = 1,
		HatModel = 1,

		Hair = 2,
		Head = 3,
		Torso = 4,
		RightArm = 5,
		LeftArm = 6,
		RightLeg = 7,
		LeftLeg = 8,

		Brim = 2,
		Band = 3,
		Crown = 4,
	},

	modelDisplayName = {
		RobotModel = "Body",
		TShirtModel = "T-Shirt",
		HatModel = "Hat",
	},

	mobileWidthCutoff = StyleLayouts.mobileWidthCutoff,

	defaultColorPickerColor = {
		h = 0,
		s = 1,
		v = 1,
	},
}

table.freeze(StyleConsts)

return StyleConsts

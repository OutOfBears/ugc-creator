export type ColorToken = {
	Color3: Color3,
	Transparency: number,
}

export type StrokeToken = {
	Color: Color3,
	Transparency: number,
	Thickness: number,
}

export type FontToken = {
	Font: Font,
	FontSize: number,
}

export type StyleTable = {
	CenterPosition: UDim2,
	CenterAnchor: Vector2,

	Colors: {
		White: Color3,
		Black: Color3,
		RainbowGradient: ColorSequence,
		ContentEmphasis: Color3,
		ContentDefault: Color3,
	},

	ActionEmphasis: ColorToken,
	OverMedia_0: ColorToken,
	OverMedia_200: ColorToken,
	Surface_0: ColorToken,
	Surface_100: ColorToken,
	Shift_200: ColorToken,
	Shift_300: ColorToken,
	Shift_400: ColorToken,
	System_Contrast: ColorToken,
	Shadow: ColorToken,

	Stroke_Default: StrokeToken,
	Stroke_Muted: StrokeToken,

	IconSize: { XSmall: UDim2, Small: UDim2, Large: UDim2 },
	Padding: {
		None: UDim,
		XXSmall: UDim,
		XSmall: UDim,
		Small: UDim,
		Medium: UDim,
		Large: UDim,
		XLarge: UDim,
		XXLarge: UDim,
	},
	Radius: { Small: UDim, Medium: UDim, Large: UDim, Circle: UDim },

	FontSize: {
		FontSize_300: number,
		FontSize_350: number,
		FontSize_400: number,
		FontSize_500: number,
	},
	FontWeight: {
		FontWeight_400: Enum.FontWeight,
		FontWeight_600: Enum.FontWeight,
		FontWeight_700: Enum.FontWeight,
	},

	IconButtonSize: UDim2,
	LocalMenuButtonSize: UDim2,
	TopBarHeight: UDim,

	PanelHeaderSize: UDim2,
	PanelSize: UDim2,
	PanelMaxSize: Vector2,
	ToolTitleSize: UDim2,

	LargePillbarIconSize: UDim2,
	LargePillbarVerticalPadding: UDim,
	LargePillbarHorizontalPadding: UDim,
	MaxLargePillbarButtons: number,

	HueSliderSize: UDim2,
	SatValPickerSize: UDim2,
	ColorDotSize: UDim2,
	ColorDotStrokeThickness: number,

	TogglePillSize: UDim2,

	SliderBarSize: UDim2,
	SliderInputPadding: UDim,
	SliderInputSize: UDim2,
	SliderHandleSize: UDim2,

	GridTileSize: UDim2,

	MainHandleDefaultRadius: number,
	MainHandleBorderThickness: number,
	SmallHandleSize: UDim2,
	SmallHandleIconSize: UDim2,
	ScaleHandlePosDegrees: number,
	RotateHandlePosDegrees: number,

	ToolbarButtonSize: UDim2,
	ToolbarParentPadding: UDim,

	ModalTwoButtonSize: UDim2,
	ModalThreeButtonSize: UDim2,
	ButtonSize: UDim2,

	SegmentedControlPadding: UDim,
	SegmentedControlButtonSize: UDim2,

	ProgressBarFrameSize: UDim2,
	ProgressBarBackgroundSize: UDim2,

	BuyButtonSize: UDim2,

	MiniBaseTileGroupSize: UDim2,
	BaseTileMinSize: Vector2,

	DisabledTransparency: number,
}

export type FontTable = {
	TitleLarge: FontToken,
	ToolTitleFont: FontToken,
	ModalTitleFont: FontToken,
	ModalBodyFont: FontToken,
	ButtonFont: FontToken,
	CounterLabelFont: FontToken,
	SegmentedControlButtonFont: FontToken,
	BuyButtonFont: FontToken,
}

export type StyleTokens = {
	style: StyleTable,
	fonts: FontTable,
}

local BUILDER_SANS_ASSET_ID = "rbxasset://fonts/families/BuilderSans.json"

local function generateRainbowColorSequence(points: number): ColorSequence
	local keypoints = {}

	for i = 0, points do
		table.insert(keypoints, ColorSequenceKeypoint.new(i / points, Color3.fromHSV(i / points, 1, 1)))
	end

	return ColorSequence.new(keypoints)
end

local style: StyleTable = {
	CenterPosition = UDim2.fromScale(0.5, 0.5),
	CenterAnchor = Vector2.new(0.5, 0.5),

	Colors = {
		White = Color3.new(1, 1, 1),
		Black = Color3.new(0, 0, 0),
		RainbowGradient = generateRainbowColorSequence(8),
		ContentEmphasis = Color3.fromHex("#F7F7F8"),
		ContentDefault = Color3.fromHex("#D5D7DD"),
	},

	ActionEmphasis = {
		Color3 = Color3.fromHex("#335FFF"),
		Transparency = 0,
	},
	OverMedia_0 = {
		Color3 = Color3.fromRGB(18, 18, 21),
		Transparency = 0.08,
	},
	OverMedia_200 = {
		Color3 = Color3.fromRGB(32, 34, 39),
		Transparency = 0.08,
	},
	Surface_0 = {
		Color3 = Color3.fromHex("#121215"),
		Transparency = 0,
	},
	Surface_100 = {
		Color3 = Color3.fromHex("#191A1F"),
		Transparency = 0,
	},
	Shift_200 = {
		Color3 = Color3.fromRGB(208, 217, 251),
		Transparency = 0.92,
	},
	Shift_300 = {
		Color3 = Color3.fromRGB(208, 217, 251),
		Transparency = 0.88,
	},
	Shift_400 = {
		Color3 = Color3.fromRGB(208, 217, 251),
		Transparency = 0.84,
	},
	System_Contrast = {
		Color3 = Color3.fromHex("F7F7F8"),
		Transparency = 0,
	},
	Shadow = {
		Color3 = Color3.fromRGB(0, 0, 0),
		Transparency = 0.5,
	},

	Stroke_Default = {
		Color = Color3.fromRGB(208, 217, 251),
		Transparency = 0.88,
		Thickness = 1,
	},
	Stroke_Muted = {
		Color = Color3.fromRGB(208, 217, 251),
		Transparency = 0.92,
		Thickness = 1,
	},

	IconSize = {
		XSmall = UDim2.fromOffset(14, 14),
		Small = UDim2.fromOffset(18, 18),
		Large = UDim2.fromOffset(24, 24),
	},
	Padding = {
		None = UDim.new(0, 0),
		XXSmall = UDim.new(0, 2),
		XSmall = UDim.new(0, 4),
		Small = UDim.new(0, 8),
		Medium = UDim.new(0, 12),
		Large = UDim.new(0, 16),
		XLarge = UDim.new(0, 20),
		XXLarge = UDim.new(0, 24),
	},
	Radius = {
		Small = UDim.new(0, 4),
		Medium = UDim.new(0, 8),
		Large = UDim.new(0, 16),
		Circle = UDim.new(0, 9999),
	},

	FontSize = {
		FontSize_300 = 15.12,
		FontSize_350 = 17.64,
		FontSize_400 = 20.16,
		FontSize_500 = 25.2,
	},
	FontWeight = {
		FontWeight_400 = Enum.FontWeight.Regular,
		FontWeight_600 = Enum.FontWeight.SemiBold,
		FontWeight_700 = Enum.FontWeight.Bold,
	},

	IconButtonSize = UDim2.fromOffset(40, 40),
	LocalMenuButtonSize = UDim2.fromOffset(36, 36),
	TopBarHeight = UDim.new(0, 58),

	PanelHeaderSize = UDim2.new(1, 0, 0, 44),
	PanelSize = UDim2.new(0, 320, 1, 0),
	-- Height only; the width component is deliberately unbounded.
	PanelMaxSize = Vector2.new(math.huge, 558),
	ToolTitleSize = UDim2.new(1, 0, 0, 16),

	LargePillbarIconSize = UDim2.fromOffset(20, 18),
	LargePillbarVerticalPadding = UDim.new(0, 11),
	LargePillbarHorizontalPadding = UDim.new(0, 10),
	MaxLargePillbarButtons = 6,

	HueSliderSize = UDim2.new(1, 0, 0, 20),
	SatValPickerSize = UDim2.new(1, 0, 0, 149),
	ColorDotSize = UDim2.fromOffset(18, 18),
	ColorDotStrokeThickness = 3,

	TogglePillSize = UDim2.fromOffset(40, 24),

	SliderBarSize = UDim2.new(1, 0, 0, 8),
	SliderInputPadding = UDim.new(0, 6),
	SliderInputSize = UDim2.new(1, 0, 0, 20),
	SliderHandleSize = UDim2.fromOffset(24, 24),

	GridTileSize = UDim2.fromOffset(80, 80),

	MainHandleDefaultRadius = 76,
	MainHandleBorderThickness = 2,
	SmallHandleSize = UDim2.fromOffset(24, 24),
	SmallHandleIconSize = UDim2.fromOffset(14, 14),
	ScaleHandlePosDegrees = -45,
	RotateHandlePosDegrees = 45,

	ToolbarButtonSize = UDim2.fromOffset(40, 40),
	ToolbarParentPadding = UDim.new(0, 22),

	ModalTwoButtonSize = UDim2.fromOffset(376, 0),
	ModalThreeButtonSize = UDim2.fromOffset(480, 0),
	-- The zero axes on these are filled in by flex.
	ButtonSize = UDim2.fromOffset(0, 40),

	SegmentedControlPadding = UDim.new(0, 6),
	SegmentedControlButtonSize = UDim2.fromOffset(140, 36),

	ProgressBarFrameSize = UDim2.new(1, 0, 0, 20),
	ProgressBarBackgroundSize = UDim2.fromOffset(0, 4),

	BuyButtonSize = UDim2.fromOffset(131, 48),

	MiniBaseTileGroupSize = UDim2.fromOffset(0, 40),
	BaseTileMinSize = Vector2.new(40, 40),

	DisabledTransparency = 0.6,
}

local fonts: FontTable = {
	TitleLarge = {
		Font = Font.new(BUILDER_SANS_ASSET_ID, style.FontWeight.FontWeight_700),
		FontSize = style.FontSize.FontSize_400,
	},

	ToolTitleFont = {
		Font = Font.new(BUILDER_SANS_ASSET_ID, style.FontWeight.FontWeight_600),
		FontSize = style.FontSize.FontSize_350,
	},

	ModalTitleFont = {
		Font = Font.new(BUILDER_SANS_ASSET_ID, style.FontWeight.FontWeight_700),
		FontSize = style.FontSize.FontSize_500,
	},
	ModalBodyFont = {
		Font = Font.new(BUILDER_SANS_ASSET_ID, style.FontWeight.FontWeight_400),
		FontSize = style.FontSize.FontSize_350,
	},
	ButtonFont = {
		Font = Font.new(BUILDER_SANS_ASSET_ID, style.FontWeight.FontWeight_600),
		FontSize = style.FontSize.FontSize_350,
	},

	CounterLabelFont = {
		Font = Font.new(BUILDER_SANS_ASSET_ID, style.FontWeight.FontWeight_600),
		FontSize = style.FontSize.FontSize_300,
	},

	SegmentedControlButtonFont = {
		Font = Font.new(BUILDER_SANS_ASSET_ID, style.FontWeight.FontWeight_600),
		FontSize = style.FontSize.FontSize_400,
	},

	BuyButtonFont = {
		Font = Font.new(BUILDER_SANS_ASSET_ID, style.FontWeight.FontWeight_600),
		FontSize = style.FontSize.FontSize_400,
	},
}

--[=[
	@class StyleTokens

	The visual design tokens the React UI styles itself from (through `useTheme`) — colors, strokes,
	spacing, component sizes, and the BuilderSans font pairings built from them.
]=]
local tokens: StyleTokens = {
	style = style,
	fonts = fonts,
}

table.freeze(tokens)

return tokens

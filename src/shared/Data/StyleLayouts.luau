local StyleTokens = require("./StyleTokens")

local styleTokens = StyleTokens.style

export type StyleLayout = {
	PanelSize: UDim2,
	PanelCornerRadius: UDim,
	PanelAutomaticSize: Enum.AutomaticSize,
	PanelAnchorPoint: Vector2,
	PanelPosition: UDim2,
	UIParentPaddingTop: UDim,
	UIParentPaddingRight: UDim,
	PanelMaxSize: Vector2,
	ToolbarDividerSize: UDim2,
	ToolbarFillDirection: Enum.FillDirection,
	ToolbarAnchorPoint: Vector2,
	ToolbarPosition: UDim2,
	ToolbarParentPaddingBottom: UDim,
	ToolbarLayoutOrder: number,
	PanelLayoutOrder: number,
	ToolbarParentFlexFill: Enum.UIFlexMode,
	PanelParentFlexFill: Enum.UIFlexMode,
	AvatarPreviewAnchorPoint: Vector2,
	AvatarPreviewPosition: UDim2,
	CoreUIVisibilityWithPanel: boolean,
	LocalMenuRightPadding: UDim,
}

export type StyleLayouts = {
	mobileWidthCutoff: number,
	mobile: StyleLayout,
	desktop: StyleLayout,
}

--[=[
	@class StyleLayouts

	The mobile and desktop layout token sets the creation UI switches between. A screen is mobile
	when both of its axes are at or under `mobileWidthCutoff`. Every layout must define every key of
	[StyleLayout].
]=]
local StyleLayouts: StyleLayouts = {
	mobileWidthCutoff = 1024,

	mobile = table.freeze({
		PanelSize = UDim2.new(0, 320, 1, 0),
		PanelCornerRadius = UDim.new(0, 0),
		PanelAutomaticSize = Enum.AutomaticSize.None,
		PanelAnchorPoint = Vector2.new(0, 0),
		PanelPosition = UDim2.fromScale(0, 0),
		UIParentPaddingTop = UDim.new(0, 0),
		UIParentPaddingRight = UDim.new(0, 0),
		PanelMaxSize = Vector2.new(math.huge, math.huge),
		ToolbarDividerSize = UDim2.fromOffset(
			styleTokens.Stroke_Default.Thickness,
			styleTokens.ToolbarButtonSize.Y.Offset
		),
		ToolbarFillDirection = Enum.FillDirection.Horizontal,
		ToolbarAnchorPoint = Vector2.new(0.5, 1),
		ToolbarPosition = UDim2.fromScale(0.5, 1),
		ToolbarParentPaddingBottom = styleTokens.Padding.XXLarge,
		ToolbarLayoutOrder = 0,
		PanelLayoutOrder = 1,
		ToolbarParentFlexFill = Enum.UIFlexMode.Fill,
		PanelParentFlexFill = Enum.UIFlexMode.None,
		AvatarPreviewAnchorPoint = Vector2.new(0.5, 1),
		AvatarPreviewPosition = UDim2.fromScale(0.5, 1),
		CoreUIVisibilityWithPanel = false,
		LocalMenuRightPadding = styleTokens.Padding.XSmall,
	}),

	desktop = table.freeze({
		PanelSize = UDim2.fromOffset(320, 0),
		PanelCornerRadius = styleTokens.Radius.Medium,
		PanelAutomaticSize = Enum.AutomaticSize.Y,
		PanelAnchorPoint = Vector2.new(1, 0),
		PanelPosition = UDim2.fromScale(1, 0),
		UIParentPaddingTop = styleTokens.Padding.Medium + styleTokens.TopBarHeight,
		UIParentPaddingRight = styleTokens.ToolbarParentPadding,
		PanelMaxSize = styleTokens.PanelMaxSize,
		ToolbarDividerSize = UDim2.fromOffset(
			styleTokens.ToolbarButtonSize.X.Offset,
			styleTokens.Stroke_Default.Thickness
		),
		ToolbarFillDirection = Enum.FillDirection.Vertical,
		ToolbarAnchorPoint = Vector2.new(0, 0),
		ToolbarPosition = UDim2.fromScale(0, 0),
		ToolbarParentPaddingBottom = UDim.new(0, 0),
		ToolbarLayoutOrder = 1,
		PanelLayoutOrder = 0,
		ToolbarParentFlexFill = Enum.UIFlexMode.None,
		PanelParentFlexFill = Enum.UIFlexMode.Fill,
		AvatarPreviewAnchorPoint = Vector2.new(1, 0),
		AvatarPreviewPosition = UDim2.fromScale(1, 0),
		CoreUIVisibilityWithPanel = true,
		LocalMenuRightPadding = styleTokens.Padding.XXLarge,
	}),
}

table.freeze(StyleLayouts)

return StyleLayouts

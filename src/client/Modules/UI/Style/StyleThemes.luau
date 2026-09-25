local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StyleTokens = require(ReplicatedStorage.Shared.Data.StyleTokens)

local styleTokens = StyleTokens.style

export type StyleThemes = {
	themeTokens: { [string]: string },
	mobileThemeTokens: { [string]: any },
	desktopThemeTokens: { [string]: any },
}

local THEME_TOKENS = {
	PanelSize = "PanelSize",
	PanelCornerRadius = "PanelCornerRadius",
	PanelAutomaticSize = "PanelAutomaticSize",
	PanelAnchorPoint = "PanelAnchorPoint",
	PanelPosition = "PanelPosition",
	UIParentPaddingTop = "UIParentPaddingTop",
	UIParentPaddingRight = "UIParentPaddingRight",
	PanelMaxSize = "PanelMaxSize",
	ToolbarDividerSize = "ToolbarDividerSize",
	ToolbarFillDirection = "ToolbarFillDirection",
	ToolbarAnchorPoint = "ToolbarAnchorPoint",
	ToolbarPosition = "ToolbarPosition",
	ToolbarParentPaddingBottom = "ToolbarParentPaddingBottom",
	ToolbarLayoutOrder = "ToolbarLayoutOrder",
	PanelLayoutOrder = "PanelLayoutOrder",
	ToolbarParentFlexFill = "ToolbarParentFlexFill",
	PanelParentFlexFill = "PanelParentFlexFill",
	AvatarPreviewAnchorPoint = "AvatarPreviewAnchorPoint",
	AvatarPreviewPosition = "AvatarPreviewPosition",
	CoreUIVisibilityWithPanel = "CoreUIVisibilityWithPanel",
	LocalMenuRightPadding = "LocalMenuRightPadding",
}

local THEME_MOBILE_TOKENS = {
	[THEME_TOKENS.PanelSize] = UDim2.new(0, 320, 1, 0),
	[THEME_TOKENS.PanelCornerRadius] = UDim.new(0, 0),
	[THEME_TOKENS.PanelAutomaticSize] = Enum.AutomaticSize.None,
	[THEME_TOKENS.PanelAnchorPoint] = Vector2.new(0, 0),
	[THEME_TOKENS.PanelPosition] = UDim2.fromScale(0, 0),
	[THEME_TOKENS.UIParentPaddingTop] = UDim.new(0, 0),
	[THEME_TOKENS.UIParentPaddingRight] = UDim.new(0, 0),
	[THEME_TOKENS.PanelMaxSize] = Vector2.new(math.huge, math.huge),
	[THEME_TOKENS.ToolbarDividerSize] = UDim2.fromOffset(
		styleTokens.Stroke_Default.Thickness,
		styleTokens.ToolbarButtonSize.Y.Offset
	),
	[THEME_TOKENS.ToolbarFillDirection] = Enum.FillDirection.Horizontal,
	[THEME_TOKENS.ToolbarAnchorPoint] = Vector2.new(0.5, 1),
	[THEME_TOKENS.ToolbarPosition] = UDim2.fromScale(0.5, 1),
	[THEME_TOKENS.ToolbarParentPaddingBottom] = styleTokens.Padding.XXLarge,
	[THEME_TOKENS.ToolbarLayoutOrder] = 0,
	[THEME_TOKENS.PanelLayoutOrder] = 1,
	[THEME_TOKENS.ToolbarParentFlexFill] = Enum.UIFlexMode.Fill,
	[THEME_TOKENS.PanelParentFlexFill] = Enum.UIFlexMode.None,
	[THEME_TOKENS.AvatarPreviewAnchorPoint] = Vector2.new(0.5, 1),
	[THEME_TOKENS.AvatarPreviewPosition] = UDim2.fromScale(0.5, 1),
	[THEME_TOKENS.CoreUIVisibilityWithPanel] = false,
	[THEME_TOKENS.LocalMenuRightPadding] = styleTokens.Padding.XSmall,
}

local THEME_DESKTOP_TOKENS = {
	[THEME_TOKENS.PanelSize] = UDim2.fromOffset(320, 0),
	[THEME_TOKENS.PanelCornerRadius] = styleTokens.Radius.Medium,
	[THEME_TOKENS.PanelAutomaticSize] = Enum.AutomaticSize.Y,
	[THEME_TOKENS.PanelAnchorPoint] = Vector2.new(1, 0),
	[THEME_TOKENS.PanelPosition] = UDim2.fromScale(1, 0),
	[THEME_TOKENS.UIParentPaddingTop] = styleTokens.Padding.Medium + styleTokens.TopBarHeight,
	[THEME_TOKENS.UIParentPaddingRight] = styleTokens.ToolbarParentPadding,
	[THEME_TOKENS.PanelMaxSize] = styleTokens.PanelMaxSize,
	[THEME_TOKENS.ToolbarDividerSize] = UDim2.fromOffset(
		styleTokens.ToolbarButtonSize.X.Offset,
		styleTokens.Stroke_Default.Thickness
	),
	[THEME_TOKENS.ToolbarFillDirection] = Enum.FillDirection.Vertical,
	[THEME_TOKENS.ToolbarAnchorPoint] = Vector2.new(0, 0),
	[THEME_TOKENS.ToolbarPosition] = UDim2.fromScale(0, 0),
	[THEME_TOKENS.ToolbarParentPaddingBottom] = UDim.new(0, 0),
	[THEME_TOKENS.ToolbarLayoutOrder] = 1,
	[THEME_TOKENS.PanelLayoutOrder] = 0,
	[THEME_TOKENS.ToolbarParentFlexFill] = Enum.UIFlexMode.None,
	[THEME_TOKENS.PanelParentFlexFill] = Enum.UIFlexMode.Fill,
	[THEME_TOKENS.AvatarPreviewAnchorPoint] = Vector2.new(1, 0),
	[THEME_TOKENS.AvatarPreviewPosition] = UDim2.fromScale(1, 0),
	[THEME_TOKENS.CoreUIVisibilityWithPanel] = true,
	[THEME_TOKENS.LocalMenuRightPadding] = styleTokens.Padding.XXLarge,
}

--[=[
	@class StyleThemes
	@client

	The mobile and desktop token sets [StyleSheet] swaps between as the screen resizes. Every theme
	table must define a value for every key in `themeTokens`: the tokens become attributes on a
	`StyleSheet` instance, and a missing one leaves the rule referencing `${Token}` unresolved.
]=]
local StyleThemes: StyleThemes = {
	themeTokens = THEME_TOKENS,
	mobileThemeTokens = THEME_MOBILE_TOKENS,
	desktopThemeTokens = THEME_DESKTOP_TOKENS,
}

return StyleThemes

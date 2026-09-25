local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local StyleConsts = require("./StyleConsts")
local StyleThemes = require("./StyleThemes")
local StyleTokens = require(ReplicatedStorage.Shared.Data.StyleTokens)

local tags = StyleConsts.tags
local styleTokens = StyleTokens.style
local fontTokens = StyleTokens.fonts
local themeTokens = StyleThemes.themeTokens

export type StyleRules = {
	lowPriorityRules: { [string]: { [string]: any } },
	standardRules: { [string]: { [string]: any } },
	highPriorityRules: { [string]: { [string]: any } },
}

local DEFAULT_RULES = {
	["TextLabel"] = {
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		BorderSizePixel = 0,
	},
	["Frame, ImageButton, TextButton, ScrollingFrame"] = {
		BorderSizePixel = 0,
	},
}

local UI_LAYOUT_RULES = {
	[`.{tags.BaseUI}::UIPadding`] = {
		PaddingBottom = styleTokens.Padding.XXLarge,
		PaddingRight = `${themeTokens.LocalMenuRightPadding}`,
	},
	[`.{tags.CoreUIWithOpenPanel}`] = {
		Visible = `${themeTokens.CoreUIVisibilityWithPanel}`,
	},

	[`.{tags.UIParent}`] = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 0),
	},
	[`.{tags.UIParent}::UIPadding`] = {
		PaddingTop = `${themeTokens.UIParentPaddingTop}`,
		PaddingRight = `${themeTokens.UIParentPaddingRight}`,
	},
	[`.{tags.UIParent}::UIListLayout`] = {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = styleTokens.Padding.Small,
	},

	[`.{tags.ToolbarParent}`] = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = `${themeTokens.ToolbarLayoutOrder}`,
	},
	[`.{tags.ToolbarParent}::UIPadding`] = {
		PaddingBottom = `${themeTokens.ToolbarParentPaddingBottom}`,
	},
	[`.{tags.ToolbarParent}::UIFlexItem`] = {
		FlexMode = `${themeTokens.ToolbarParentFlexFill}`,
	},

	[`.{tags.PanelParent}`] = {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = `${themeTokens.PanelLayoutOrder}`,
	},
	[`.{tags.PanelParent}::UIFlexItem`] = {
		FlexMode = `${themeTokens.PanelParentFlexFill}`,
	},

	[`.{tags.PreviewUIParent}`] = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	},
	[`.{tags.PreviewUIParent}::UIPadding`] = {
		PaddingLeft = styleTokens.Padding.XXLarge,
		PaddingRight = styleTokens.Padding.XXLarge,
		PaddingBottom = styleTokens.Padding.XXLarge,
		PaddingTop = if GuiService:IsTenFootInterface()
			then styleTokens.Padding.Medium + styleTokens.TopBarHeight
			else styleTokens.Padding.Medium,
	},
	[`.{tags.AvatarPreviewSwitcher}`] = {
		Position = `${themeTokens.AvatarPreviewPosition}`,
		AnchorPoint = `${themeTokens.AvatarPreviewAnchorPoint}`,
	},
}

local LOCAL_MENU_RULES = {
	[`.{tags.LocalMenu}`] = {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.XY,
	},
	[`.{tags.LocalMenu}::UIPadding`] = {
		PaddingBottom = styleTokens.Padding.XXSmall,
		PaddingRight = `${themeTokens.LocalMenuRightPadding}`,
	},
	[`.{tags.LocalMenu}::UIListLayout`] = {
		Padding = styleTokens.Padding.Medium,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalFlex = Enum.UIFlexAlignment.None,
	},

	[`.{tags.LocalMenuConsole}`] = {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(0, styleTokens.TopBarHeight.Offset),
		AutomaticSize = Enum.AutomaticSize.X,
	},
	[`.{tags.LocalMenuConsole}::UIPadding`] = {
		PaddingTop = styleTokens.Padding.Medium,
		PaddingRight = `${themeTokens.LocalMenuRightPadding}`,
	},
	[`.{tags.LocalMenuConsole}::UIListLayout`] = {
		Padding = styleTokens.Padding.Medium,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalFlex = Enum.UIFlexAlignment.None,
	},

	[`.{tags.LocalMenuButtonGroup}`] = {
		BackgroundColor3 = styleTokens.OverMedia_0.Color3,
		BackgroundTransparency = styleTokens.OverMedia_0.Transparency,
		AutomaticSize = Enum.AutomaticSize.XY,
	},
	[`.{tags.LocalMenuButtonGroup}::UIPadding`] = {
		PaddingTop = styleTokens.Padding.XSmall,
		PaddingBottom = styleTokens.Padding.XSmall,
		PaddingLeft = styleTokens.Padding.XSmall,
		PaddingRight = styleTokens.Padding.XSmall,
	},
	[`.{tags.LocalMenuButtonGroup}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},
	[`.{tags.LocalMenuButtonGroup}::UIListLayout`] = {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = styleTokens.Padding.None,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},

	[`.{tags.LocalMenuButton}`] = {
		Size = styleTokens.LocalMenuButtonSize,
		BackgroundTransparency = 1,
	},
	[`.{tags.LocalMenuButton}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},
	[`.{tags.LocalMenuButton} > ImageLabel`] = {
		Size = styleTokens.IconSize.Small,
		Position = styleTokens.CenterPosition,
		AnchorPoint = styleTokens.CenterAnchor,
	},
}

local PANEL_RULES = {
	[`.{tags.Panel}`] = {
		BackgroundColor3 = styleTokens.Surface_0.Color3,
		BackgroundTransparency = styleTokens.Surface_0.Transparency,
		Size = `${themeTokens.PanelSize}`,
		AutomaticSize = `${themeTokens.PanelAutomaticSize}`,
		AnchorPoint = `${themeTokens.PanelAnchorPoint}`,
		Position = `${themeTokens.PanelPosition}`,
	},
	[`.{tags.Panel}::UIPadding`] = {
		PaddingTop = styleTokens.Padding.Small,
		PaddingLeft = styleTokens.Padding.Small,
		-- Wider than the left inset on purpose: device safe-area insets eat into this edge.
		PaddingRight = styleTokens.Padding.Medium,
		PaddingBottom = styleTokens.Padding.XLarge,
	},
	[`.{tags.Panel}::UIListLayout`] = {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = styleTokens.Padding.Large,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},
	[`.{tags.Panel}::UICorner`] = {
		CornerRadius = `${themeTokens.PanelCornerRadius}`,
	},
	[`.{tags.Panel}::UISizeConstraint`] = {
		MaxSize = `${themeTokens.PanelMaxSize}`,
	},

	[`.{tags.PanelHeader}`] = {
		BackgroundTransparency = 1,
		Size = styleTokens.PanelHeaderSize,
	},
	[`.{tags.PanelHeader}::UIPadding`] = {
		PaddingLeft = styleTokens.Padding.XLarge,
		PaddingRight = styleTokens.Padding.Medium,
	},
	[`.{tags.PanelHeader}::UIListLayout`] = {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = styleTokens.Padding.Medium,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
	},
	[`.{tags.PanelHeader} > TextLabel`] = {
		FontFace = fontTokens.TitleLarge.Font,
		TextSize = fontTokens.TitleLarge.FontSize,
		TextColor3 = styleTokens.Colors.ContentEmphasis,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 1,
	},

	[`.{tags.PanelHeader} > Frame`] = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
	},
	[`.{tags.PanelHeader} > Frame::UIListLayout`] = {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = styleTokens.Padding.XXSmall,
		SortOrder = Enum.SortOrder.LayoutOrder,
		ItemLineAlignment = Enum.ItemLineAlignment.Center,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	},

	[`.{tags.PanelToolsContainer}`] = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = `${themeTokens.PanelAutomaticSize}`,
	},
	[`.{tags.PanelToolsContainer}::UIFlexItem`] = {
		FlexMode = Enum.UIFlexMode.Fill,
	},
	[`.{tags.PanelToolsContainer}::UIPadding`] = {
		PaddingLeft = styleTokens.Padding.XLarge,
		PaddingRight = styleTokens.Padding.XLarge,
		PaddingBottom = styleTokens.Padding.XLarge,
	},
	[`.{tags.PanelToolsContainer}::UIListLayout, .{tags.ScrollFrame}::UIListLayout`] = {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = styleTokens.Padding.XLarge,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
	},

	[`.{tags.ScrollFrame}`] = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromScale(1, 0),
	},
	[`.{tags.ScrollFrame}::UIFlexItem`] = {
		FlexMode = Enum.UIFlexMode.Fill,
	},

	[`.{tags.ToolFrame}`] = {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	},
	[`.{tags.ToolFrame}::UIListLayout`] = {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = styleTokens.Padding.Large,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},

	[`.{tags.ToolTitle}`] = {
		Size = styleTokens.ToolTitleSize,
		BackgroundTransparency = 1,
	},
	[`.{tags.ToolTitle}::UIListLayout`] = {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = styleTokens.Padding.Small,
		SortOrder = Enum.SortOrder.LayoutOrder,
		ItemLineAlignment = Enum.ItemLineAlignment.Center,
		HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
	},
	[`.{tags.ToolTitle} > TextLabel`] = {
		FontFace = fontTokens.ToolTitleFont.Font,
		TextColor3 = styleTokens.Colors.ContentEmphasis,
		TextSize = fontTokens.ToolTitleFont.FontSize,
		AutomaticSize = Enum.AutomaticSize.XY,
	},
}

local COLOR_PICKER_RULES = {
	[`.{tags.ColorPicker}`] = {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	},
	[`.{tags.ColorPicker}::UIListLayout`] = {
		Padding = if not GuiService:IsTenFootInterface()
			then styleTokens.Padding.Small
			else styleTokens.Padding.XXLarge,
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},

	[`.{tags.SatValPicker}`] = {
		Size = styleTokens.SatValPickerSize,
	},
	[`.{tags.SatValPicker}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Small,
	},

	[`.{tags.SatGradient}`] = {
		BackgroundColor3 = styleTokens.Colors.White,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	},
	[`.{tags.SatGradient}::UIGradient`] = {
		Transparency = NumberSequence.new(0, 1),
	},
	[`.{tags.SatGradient}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Small,
	},

	[`.{tags.ValGradient}`] = {
		BackgroundColor3 = styleTokens.Colors.Black,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	},
	[`.{tags.ValGradient}::UIGradient`] = {
		Transparency = NumberSequence.new(1, 0),
		Rotation = 90,
	},
	[`.{tags.ValGradient}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Small,
	},

	[`.{tags.HuePicker}`] = {
		BackgroundColor3 = styleTokens.Colors.White,
		Size = styleTokens.HueSliderSize,
	},
	[`.{tags.HuePicker}::UIGradient`] = {
		Color = styleTokens.Colors.RainbowGradient,
	},
	[`.{tags.HuePicker}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},

	[`.{tags.ColorDot}`] = {
		Size = styleTokens.ColorDotSize,
		AnchorPoint = styleTokens.CenterAnchor,
		ZIndex = 100,
		-- A non-zero rotation opts the dot out of the ancestor scrolling frame's ClipsDescendants.
		Rotation = 90,
	},
	[`.{tags.ColorDot}::UIStroke`] = {
		Color = styleTokens.System_Contrast.Color3,
		Transparency = styleTokens.System_Contrast.Transparency,
		Thickness = styleTokens.ColorDotStrokeThickness,
	},
	[`.{tags.ColorDot}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},

	[`.{tags.OpacityPicker}`] = {
		BackgroundTransparency = 1,
		Size = styleTokens.HueSliderSize,
		Image = CreationIcons.uiImages.OpacityPicker,
	},
	[`.{tags.OpacityPicker}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},

	[`.{tags.OpacityOverlay}`] = {
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1),
	},
	[`.{tags.OpacityOverlay}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},
	-- Selects the UIGradient itself rather than a pseudo-instance: [ColorPicker] restyles it live.
	[`.{tags.OpacityGradient}`] = {
		Transparency = NumberSequence.new(1, 0),
	},
}

local TOOLBAR_RULES = {
	[`.{tags.Divider}`] = {
		Size = `${themeTokens.ToolbarDividerSize}`,
		BackgroundColor3 = styleTokens.Stroke_Default.Color,
		BackgroundTransparency = styleTokens.Stroke_Default.Transparency,
	},

	[`.{tags.ToolbarButton}`] = {
		BackgroundTransparency = 1,
		Size = styleTokens.ToolbarButtonSize,
	},
	[`.{tags.ToolbarButton} > ImageLabel`] = {
		Size = styleTokens.IconSize.Large,
		Position = styleTokens.CenterPosition,
		AnchorPoint = styleTokens.CenterAnchor,
	},

	[`.{tags.ToolbarButtonGroup}`] = {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
	},
	[`.{tags.ToolbarButtonGroup}::UIListLayout`] = {
		FillDirection = `${themeTokens.ToolbarFillDirection}`,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},
	[`.{tags.ToolbarButtonGroup}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Small,
	},

	[`.{tags.Toolbar}`] = {
		BackgroundColor3 = styleTokens.Surface_100.Color3,
		BackgroundTransparency = styleTokens.Surface_100.Transparency,
		AutomaticSize = Enum.AutomaticSize.XY,
		AnchorPoint = `${themeTokens.ToolbarAnchorPoint}`,
		Position = `${themeTokens.ToolbarPosition}`,
	},
	[`.{tags.Toolbar}::UIPadding`] = {
		PaddingTop = styleTokens.Padding.XSmall,
		PaddingBottom = styleTokens.Padding.XSmall,
		PaddingLeft = styleTokens.Padding.XSmall,
		PaddingRight = styleTokens.Padding.XSmall,
	},
	[`.{tags.Toolbar}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Medium,
	},
	[`.{tags.Toolbar}::UIStroke`] = {
		Color = styleTokens.Stroke_Default.Color,
		Transparency = styleTokens.Stroke_Default.Transparency,
		Thickness = 1,
	},
	[`.{tags.Toolbar}::UIListLayout`] = {
		Padding = styleTokens.Padding.XSmall,
		FillDirection = `${themeTokens.ToolbarFillDirection}`,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},
}

local MODAL_RULES = {
	[`.{tags.ModalFrame}`] = {
		BackgroundColor3 = styleTokens.Surface_100.Color3,
		BackgroundTransparency = styleTokens.Surface_100.Transparency,

		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),

		-- Width comes from the button count and is set by [Modal].
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 10,
	},
	[`.{tags.ModalFrame}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Large,
	},
	[`.{tags.ModalFrame}::UIPadding`] = {
		PaddingTop = styleTokens.Padding.XLarge,
		PaddingBottom = styleTokens.Padding.XLarge,
		PaddingLeft = styleTokens.Padding.XLarge,
		PaddingRight = styleTokens.Padding.XLarge,
	},
	[`.{tags.ModalFrame}::UIStroke`] = {
		Color = styleTokens.Stroke_Muted.Color,
		Transparency = styleTokens.Stroke_Muted.Transparency,
		Thickness = styleTokens.Stroke_Muted.Thickness,
	},
	[`.{tags.ModalFrame}::UIListLayout`] = {
		Padding = styleTokens.Padding.XLarge,
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},

	[`.{tags.ModalTextFrame}`] = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	},
	[`.{tags.ModalTextFrame}::UIListLayout`] = {
		Padding = styleTokens.Padding.XSmall,
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},
	[`.{tags.ModalTextFrame}::UIPadding`] = {
		PaddingRight = styleTokens.Padding.XXLarge,
	},

	[`.{tags.ModalTitle}, .{tags.ModalBody}`] = {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
	},
	[`.{tags.ModalTitle}`] = {
		FontFace = fontTokens.ModalTitleFont.Font,
		TextSize = fontTokens.ModalTitleFont.FontSize,
		TextColor3 = styleTokens.Colors.ContentEmphasis,
	},
	[`.{tags.ModalBody}`] = {
		FontFace = fontTokens.ModalBodyFont.Font,
		TextSize = fontTokens.ModalBodyFont.FontSize,
		TextColor3 = styleTokens.Colors.ContentDefault,
	},

	[`.{tags.Overlay}`] = {
		BackgroundColor3 = styleTokens.Shadow.Color3,
		BackgroundTransparency = styleTokens.Shadow.Transparency,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		-- It is a TextButton only so it sinks input; it must not read or behave as a button.
		Active = false,
		Selectable = false,
		AutoButtonColor = false,
	},
}

local GRID_RULES = {
	[`.{tags.BaseTile}`] = {
		BackgroundColor3 = styleTokens.OverMedia_200.Color3,
		BackgroundTransparency = styleTokens.OverMedia_200.Transparency,
		Size = UDim2.fromScale(1, 1),
	},
	[`.{tags.BaseTile}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Medium,
	},
	[`.{tags.BaseTile}::UIAspectRatioConstraint`] = {
		AspectRatio = 1,
	},

	[`.{tags.BaseTileButton}`] = {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
	},
	[`.{tags.BaseTileButton} > ImageLabel`] = {
		Size = UDim2.fromScale(1, 1),
	},

	[`.{tags.TileGrid}`] = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	},
	[`.{tags.TileGrid}::UIPadding`] = {
		PaddingTop = styleTokens.Padding.XXSmall,
		PaddingBottom = styleTokens.Padding.XXSmall,
		PaddingLeft = styleTokens.Padding.XXSmall,
		PaddingRight = styleTokens.Padding.XXSmall,
	},
	[`.{tags.TileGrid}::UIGridLayout`] = {
		CellPadding = UDim2.new(styleTokens.Padding.Small, styleTokens.Padding.Small),
		CellSize = styleTokens.GridTileSize,
	},
}

local ITEM_SELECTOR_RULES = {
	[`.{tags.ItemSelectorFrame}`] = {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	},
	[`.{tags.ItemSelectorFrame}::UIListLayout`] = {
		Padding = styleTokens.Padding.Medium,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	},

	[`.{tags.ItemSelectorFlexFrame}`] = {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
	},
	[`.{tags.ItemSelectorFlexFrame}::UIFlexItem`] = {
		FlexMode = Enum.UIFlexMode.Fill,
	},

	[`.{tags.ItemSelectorScrollFrame}`] = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		AutomaticSize = Enum.AutomaticSize.Y,

		ScrollBarThickness = 4,
		ScrollBarImageColor3 = styleTokens.Shift_400.Color3,
		ScrollBarImageTransparency = styleTokens.Shift_400.Transparency,
		HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,

		TopImage = CreationIcons.scrollBar.Top,
		MidImage = CreationIcons.scrollBar.Middle,
		BottomImage = CreationIcons.scrollBar.Bottom,
	},
	[`.{tags.ItemSelectorScrollFrame}::UIPadding`] = {
		PaddingBottom = styleTokens.Padding.XSmall,
	},

	[`.{tags.CounterLabel}`] = {
		FontFace = fontTokens.CounterLabelFont.Font,
		TextSize = fontTokens.CounterLabelFont.FontSize,
		TextColor3 = styleTokens.Colors.ContentDefault,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
	},
	[`.{tags.CounterFrame}`] = {
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
	},

	[`.{tags.MiniBaseTileGroup}`] = {
		BackgroundTransparency = 1,
		Size = styleTokens.MiniBaseTileGroupSize,
		AutomaticSize = Enum.AutomaticSize.X,
	},
	[`.{tags.MiniBaseTileGroup}::UIListLayout`] = {
		Padding = styleTokens.Padding.Small,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},
	[`.{tags.MiniBaseTileSelected}::UIStroke`] = {
		Color = styleTokens.System_Contrast.Color3,
		Transparency = styleTokens.System_Contrast.Transparency,
		Thickness = styleTokens.Stroke_Default.Thickness,
		BorderStrokePosition = Enum.BorderStrokePosition.Inner,
	},
}

local BUTTON_RULES = {
	[`.{tags.MediumIconButton}`] = {
		Size = styleTokens.IconButtonSize,
		BackgroundTransparency = 1,
	},

	[`.{tags.MediumIconButton} > ImageLabel`] = {
		Size = styleTokens.IconSize.Large,
		Position = styleTokens.CenterPosition,
		AnchorPoint = styleTokens.CenterAnchor,
	},

	[`.{tags.ButtonFrame}`] = {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	},
	[`.{tags.ButtonFrame}::UIListLayout`] = {
		Padding = styleTokens.Padding.Small,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
	},

	[`.{tags.DefaultButton}`] = {
		Size = styleTokens.ButtonSize,
		BackgroundColor3 = styleTokens.Shift_300.Color3,
		BackgroundTransparency = styleTokens.Shift_300.Transparency,

		FontFace = fontTokens.ButtonFont.Font,
		TextSize = fontTokens.ButtonFont.FontSize,
		TextColor3 = styleTokens.Colors.ContentEmphasis,
	},
	[`.{tags.DefaultButton}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Medium,
	},
	[`.{tags.DefaultButton}::UIPadding`] = {
		PaddingLeft = styleTokens.Padding.Large,
		PaddingRight = styleTokens.Padding.Large,
	},
}

local HORIZONTAL_PILLBAR_RULES = {
	[`.{tags.HorizontalPillbar}`] = {
		BackgroundColor3 = styleTokens.Shift_300.Color3,
		BackgroundTransparency = styleTokens.Shift_300.Transparency,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	},
	[`.{tags.HorizontalPillbar}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},
	[`.{tags.HorizontalPillbar}::UIPadding`] = {
		PaddingTop = styleTokens.Padding.XSmall,
		PaddingLeft = styleTokens.Padding.XSmall,
		PaddingRight = styleTokens.Padding.XSmall,
		PaddingBottom = styleTokens.Padding.XSmall,
	},
	[`.{tags.HorizontalPillbar}::UIListLayout`] = {
		Padding = styleTokens.Padding.XSmall,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
	},

	[`.{tags.LargePillbarButton}, .{tags.SmallPillbarButton}`] = {
		BackgroundTransparency = 1,

		Size = UDim2.fromScale(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
	},
	[`.{tags.LargePillbarButton}::UICorner, .{tags.SmallPillbarButton}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},
	-- Centering via layout alignment rather than an anchor point: anchors fight AutomaticSize.
	[`.{tags.LargePillbarButton}::UIListLayout, .{tags.SmallPillbarButton}::UIListLayout`] = {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	},
	[`.{tags.LargePillbarButton}::UIPadding`] = {
		PaddingTop = styleTokens.LargePillbarVerticalPadding,
		PaddingLeft = styleTokens.LargePillbarHorizontalPadding,
		PaddingRight = styleTokens.LargePillbarHorizontalPadding,
		PaddingBottom = styleTokens.LargePillbarVerticalPadding,
	},
	[`.{tags.SmallPillbarButton}::UIPadding`] = {
		PaddingTop = styleTokens.Padding.XSmall,
		PaddingLeft = styleTokens.Padding.XSmall,
		PaddingRight = styleTokens.Padding.XSmall,
		PaddingBottom = styleTokens.Padding.XSmall,
	},

	[`.{tags.LargePillbarButton} > ImageLabel`] = {
		Size = styleTokens.LargePillbarIconSize,
	},
	[`.{tags.SmallPillbarButton} > ImageLabel`] = {
		Size = styleTokens.IconSize.Small,
	},
}

local TOGGLE_RULES = {
	[`.{tags.ToggleFrame}`] = {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	},
	[`.{tags.ToggleFrame}::UIListLayout`] = {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = styleTokens.Padding.Small,
		ItemLineAlignment = Enum.ItemLineAlignment.Center,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	},

	[`.{tags.TogglePill}`] = {
		Size = styleTokens.TogglePillSize,
		Image = CreationIcons.uiImages.ToggleOff,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
	},

	[`.{tags.ToggleLabel}`] = {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		FontFace = fontTokens.ToolTitleFont.Font,
		TextSize = fontTokens.ToolTitleFont.FontSize,
		TextColor3 = styleTokens.Colors.ContentDefault,
	},
}

local PROGRESS_BAR_RULES = {
	[`.{tags.ProgressBarFrame}`] = {
		BackgroundTransparency = 1,
		Size = styleTokens.ProgressBarFrameSize,
	},
	[`.{tags.ProgressBarFrame}::UIListLayout`] = {
		Padding = styleTokens.Padding.Small,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		ItemLineAlignment = Enum.ItemLineAlignment.Center,
	},

	[`.{tags.ProgressBarBackground}`] = {
		Size = styleTokens.ProgressBarBackgroundSize,
		BackgroundColor = styleTokens.Shift_200.Color3,
		BackgroundTransparency = styleTokens.Shift_200.Transparency,
	},
	[`.{tags.ProgressBarBackground}::UIFlexItem`] = {
		FlexMode = Enum.UIFlexMode.Fill,
	},
	[`.{tags.ProgressBarBackground}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},

	[`.{tags.ProgressBarLabel}`] = {
		AutomaticSize = Enum.AutomaticSize.XY,
		TextColor = styleTokens.Colors.ContentDefault,
		FontFace = fontTokens.CounterLabelFont.Font,
		TextSize = fontTokens.CounterLabelFont.FontSize,
	},

	-- Size is dynamic and set by [ProgressBar].
	[`.{tags.ProgressBarProgress}`] = {
		BackgroundColor = styleTokens.Colors.ContentEmphasis,
	},
	[`.{tags.ProgressBarProgress}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},
}

local SLIDER_RULES = {
	[`.{tags.SliderFrame}`] = {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	},
	[`.{tags.SliderFrame}::UIPadding`] = {
		PaddingTop = styleTokens.Padding.Medium,
		PaddingBottom = styleTokens.Padding.Medium,
	},
	[`.{tags.SliderInput}`] = {
		Size = styleTokens.SliderInputSize,
		BackgroundTransparency = 1,
	},

	[`.{tags.SliderBar}`] = {
		Size = styleTokens.SliderBarSize,
		BackgroundColor3 = styleTokens.Shift_300.Color3,
		BackgroundTransparency = styleTokens.Shift_300.Transparency,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
	},
	[`.{tags.SliderBar}::UICorner, .{tags.SliderBar} > Frame::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},
	-- The bar's only child Frame is the filled portion.
	[`.{tags.SliderBar} > Frame`] = {
		BackgroundColor3 = styleTokens.System_Contrast.Color3,
		BackgroundTransparency = styleTokens.System_Contrast.Transparency,
	},

	[`.{tags.SliderHandle}`] = {
		Size = styleTokens.SliderHandleSize,
		BackgroundColor3 = styleTokens.System_Contrast.Color3,
		BackgroundTransparency = styleTokens.System_Contrast.Transparency,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		-- A non-zero rotation opts the handle out of the ancestor scrolling frame's ClipsDescendants.
		Rotation = 90,
	},
	[`.{tags.SliderHandle}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},
}

local SEGMENTED_CONTROL_RULES = {
	[`.{tags.SegmentedControl}`] = {
		BackgroundColor3 = styleTokens.Surface_100.Color3,
		BackgroundTransparency = styleTokens.Surface_100.Transparency,
		AutomaticSize = Enum.AutomaticSize.XY,
	},
	[`.{tags.SegmentedControl}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Medium,
	},
	[`.{tags.SegmentedControl}::UIPadding`] = {
		PaddingLeft = styleTokens.SegmentedControlPadding,
		PaddingRight = styleTokens.SegmentedControlPadding,
		PaddingTop = styleTokens.SegmentedControlPadding,
		PaddingBottom = styleTokens.SegmentedControlPadding,
	},
	[`.{tags.SegmentedControl}::UIListLayout`] = {
		Padding = styleTokens.Padding.XSmall,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},

	[`.{tags.SegmentedControlButton}`] = {
		BackgroundTransparency = 1,
		Size = styleTokens.SegmentedControlButtonSize,

		FontFace = fontTokens.SegmentedControlButtonFont.Font,
		TextSize = fontTokens.SegmentedControlButtonFont.FontSize,
		TextColor3 = styleTokens.Colors.ContentDefault,

		TextTruncate = Enum.TextTruncate.AtEnd,
	},
	[`.{tags.SegmentedControlButton}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Small,
	},
	[`.{tags.SegmentedControlButton}::UIPadding`] = {
		PaddingLeft = styleTokens.Padding.Small,
		PaddingRight = styleTokens.Padding.Small,
	},
}

local EDITING_HANDLE_RULES = {
	-- Size is set by the tool driving the handle.
	[`.{tags.MainHandle}`] = {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	},
	[`.{tags.MainHandle}::UIStroke`] = {
		Color = styleTokens.Colors.White,
		Transparency = 0,
		Thickness = styleTokens.MainHandleBorderThickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	},
	[`.{tags.MainHandle}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},

	[`.{tags.SmallHandle}`] = {
		Size = styleTokens.SmallHandleSize,
		BackgroundColor3 = styleTokens.Colors.White,
		AnchorPoint = Vector2.new(0.5, 0.5),
	},
	[`.{tags.SmallHandle} > ImageLabel`] = {
		Size = styleTokens.SmallHandleIconSize,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	},
	[`.{tags.SmallHandle}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},
}

local HIGH_PRIORITY_RULE_MAP = {
	[`.{tags.ButtonSelected}`] = {
		BackgroundColor3 = styleTokens.Shift_300.Color3,
		BackgroundTransparency = styleTokens.Shift_300.Transparency,
		AutoButtonColor = false,
		TextColor = styleTokens.Colors.ContentEmphasis,
	},

	[`.{tags.Hidden}`] = {
		Visible = false,
	},

	[`.{tags.ToggleFrameLeft}`] = {
		Size = UDim2.fromScale(0, 0),
	},
	[`.{tags.ToggleFrameLeft}::UIListLayout`] = {
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
	},

	[`.{tags.EmphasisButton}`] = {
		BackgroundColor3 = styleTokens.ActionEmphasis.Color3,
		BackgroundTransparency = styleTokens.ActionEmphasis.Transparency,
	},

	[`.{tags.BuyButton}`] = {
		Size = styleTokens.BuyButtonSize,
		Position = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(1, 1),
		FontFace = fontTokens.BuyButtonFont.Font,
		TextSize = fontTokens.BuyButtonFont.FontSize,
	},
}

local UV_CANVAS_RULES = {
	[`.{tags.UVCanvasContainer}`] = {
		BackgroundColor3 = styleTokens.Surface_0.Color3,
		BackgroundTransparency = styleTokens.Surface_0.Transparency,
	},
	[`.{tags.UVCanvasContainer}::UIPadding`] = {
		PaddingTop = styleTokens.Padding.Small,
		PaddingBottom = styleTokens.Padding.Small,
		PaddingLeft = styleTokens.Padding.Small,
		PaddingRight = styleTokens.Padding.Small,
	},
	[`.{tags.UVCanvasContainer}::UIListLayout`] = {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = styleTokens.Padding.Small,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},
	[`.{tags.UVCanvasContainer}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Medium,
	},

	[`.{tags.UVCanvasHeader}`] = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	},
	[`.{tags.UVCanvasHeader}::UIListLayout`] = {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = styleTokens.Padding.Medium,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
	},

	[`.{tags.UVCanvasHeaderButton}`] = {
		Size = styleTokens.ButtonSize,
		AutomaticSize = Enum.AutomaticSize.X,
	},

	[`.{tags.UVCanvas}`] = {
		BackgroundColor3 = styleTokens.Surface_100.Color3,
		BackgroundTransparency = styleTokens.Surface_100.Transparency,
		Size = UDim2.fromScale(1, 0),
	},
	[`.{tags.UVCanvas}::UIFlexItem`] = {
		FlexMode = Enum.UIFlexMode.Fill,
	},
	[`.{tags.UVCanvas}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Small,
	},

	[`.{tags.UVCanvasResizeGrip}`] = {
		Size = styleTokens.SmallHandleSize,
		BackgroundTransparency = 1,
		FontFace = fontTokens.ToolTitleFont.Font,
		TextSize = fontTokens.ToolTitleFont.FontSize,
		TextColor3 = styleTokens.Colors.ContentDefault,
		AutoButtonColor = false,
	},

	[`.{tags.UVCanvasCursor}`] = {
		BackgroundTransparency = 1,
	},
	[`.{tags.UVCanvasCursor}::UIStroke`] = {
		Color = styleTokens.Colors.White,
		Thickness = styleTokens.MainHandleBorderThickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	},
	[`.{tags.UVCanvasCursor}::UICorner`] = {
		CornerRadius = styleTokens.Radius.Circle,
	},
}

local RULES = {
	UI_LAYOUT_RULES,

	LOCAL_MENU_RULES,
	PANEL_RULES,
	COLOR_PICKER_RULES,
	TOOLBAR_RULES,
	MODAL_RULES,
	GRID_RULES,
	ITEM_SELECTOR_RULES,

	BUTTON_RULES,
	HORIZONTAL_PILLBAR_RULES,
	TOGGLE_RULES,
	PROGRESS_BAR_RULES,
	SLIDER_RULES,
	SEGMENTED_CONTROL_RULES,
	EDITING_HANDLE_RULES,
	UV_CANVAS_RULES,
}

local function compileStandardRules(): { [string]: { [string]: any } }
	local compiledRules = {}

	for _, ruleSet in RULES do
		for selector, properties in ruleSet do
			compiledRules[selector] = properties
		end
	end

	return compiledRules
end

--[=[
	@class StyleRules
	@client

	Every style rule in the creation UI, as CSS-like selector to property tables. Selectors match the
	tag ids in [StyleConsts].tags; values come from [StyleTokens] and, where a property differs
	between mobile and desktop, from a `${Token}` reference into [StyleThemes].

	A new rule goes in the table for its component (or a new table added to `RULES`); the three
	exported sets are what [StyleSheet] compiles, at priority 0, 50 and 100 respectively.
]=]
local StyleRules: StyleRules = {
	lowPriorityRules = DEFAULT_RULES,
	standardRules = compileStandardRules(),
	highPriorityRules = HIGH_PRIORITY_RULE_MAP,
}

return StyleRules

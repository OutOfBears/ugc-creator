local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local IconButton = require("./IconButton")
local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo

export type LocalMenuButton = {
	icon: string,
	onActivated: () -> (),
}

export type LocalMenuProps = {
	groups: { { LocalMenuButton } },
	visible: boolean,
}

--[=[
	@class LocalMenu
	@client

	The top-bar menu of general editing controls — reset, preview, exit — as pills of grouped icon
	buttons. On a ten-foot interface it drops to clear the console safe area.
]=]
local LocalMenu = memo(function(props: LocalMenuProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local isConsole = GuiService:IsTenFootInterface()

	local groups: { [string]: any } = {
		padding = createElement("UIPadding", {
			PaddingBottom = if isConsole then nil else tokens.Padding.XXSmall,
			PaddingRight = theme.layout.LocalMenuRightPadding,
			PaddingTop = if isConsole then tokens.Padding.Medium else nil,
		}),
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalFlex = Enum.UIFlexAlignment.None,
			Padding = tokens.Padding.Medium,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for groupIndex, group in props.groups do
		local buttons: { [string]: any } = {
			padding = createElement("UIPadding", {
				PaddingBottom = tokens.Padding.XSmall,
				PaddingLeft = tokens.Padding.XSmall,
				PaddingRight = tokens.Padding.XSmall,
				PaddingTop = tokens.Padding.XSmall,
			}),
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Circle,
			}),
			listLayout = createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = tokens.Padding.None,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}

		for buttonIndex, button in group do
			buttons[`button{buttonIndex}`] = createElement(IconButton, {
				icon = button.icon,
				iconSize = tokens.IconSize.Small,
				onActivated = button.onActivated,
				native = {
					BackgroundTransparency = 1,
					LayoutOrder = buttonIndex * 2,
					Size = tokens.LocalMenuButtonSize,
				},
			}, {
				corner = createElement("UICorner", {
					CornerRadius = tokens.Radius.Circle,
				}),
			})
		end

		groups[`group{groupIndex}`] = createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = tokens.OverMedia_0.Color3,
			BackgroundTransparency = tokens.OverMedia_0.Transparency,
			BorderSizePixel = 0,
			LayoutOrder = groupIndex,
		}, buttons)
	end

	return createElement("Frame", {
		AnchorPoint = if isConsole then Vector2.new(1, 0) else Vector2.new(1, 1),
		AutomaticSize = if isConsole then Enum.AutomaticSize.X else Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = if isConsole then UDim2.fromScale(1, 0) else UDim2.fromScale(1, 1),
		Size = if isConsole then UDim2.fromOffset(0, tokens.TopBarHeight.Offset) else nil,
		Visible = props.visible,
	}, groups)
end)

return LocalMenu

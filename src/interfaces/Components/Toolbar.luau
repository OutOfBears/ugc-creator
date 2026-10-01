local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local IconButton = require("./IconButton")
local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo

export type ToolbarButton = {
	icon: string,
	mutedIcon: string?,
}

export type ToolbarGroup = {
	key: string,
	buttons: { ToolbarButton },
	selected: boolean,
	activeButton: number?,
	visible: boolean?,
	onPress: (buttonIndex: number) -> (),
}

export type ToolbarProps = {
	groups: { ToolbarGroup },
}

--[=[
	@class Toolbar
	@client

	The tool strip: groups of icon buttons with one group selected. A selected group expands to
	show all its buttons behind dividers, the active one in full color and the rest muted; any
	other group shows only its first button.
]=]
local Toolbar = memo(function(props: ToolbarProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local layout = theme.layout

	local groups: { [string]: any } = {
		padding = createElement("UIPadding", {
			PaddingBottom = tokens.Padding.XSmall,
			PaddingLeft = tokens.Padding.XSmall,
			PaddingRight = tokens.Padding.XSmall,
			PaddingTop = tokens.Padding.XSmall,
		}),
		corner = createElement("UICorner", {
			CornerRadius = tokens.Radius.Medium,
		}),
		stroke = createElement("UIStroke", {
			Color = tokens.Stroke_Default.Color,
			Thickness = 1,
			Transparency = tokens.Stroke_Default.Transparency,
		}),
		listLayout = createElement("UIListLayout", {
			FillDirection = layout.ToolbarFillDirection,
			Padding = tokens.Padding.XSmall,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for groupIndex, group in props.groups do
		local children: { [string]: any } = {
			listLayout = createElement("UIListLayout", {
				FillDirection = layout.ToolbarFillDirection,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Small,
			}),
		}

		for buttonIndex, button in group.buttons do
			local shown = buttonIndex == 1 or group.selected
			local isActive = group.activeButton == buttonIndex
			local useMutedIcon = group.selected and not isActive and button.mutedIcon ~= nil

			if buttonIndex > 1 then
				children[`divider{buttonIndex}`] = createElement("Frame", {
					BackgroundColor3 = tokens.Stroke_Default.Color,
					BackgroundTransparency = tokens.Stroke_Default.Transparency,
					BorderSizePixel = 0,
					LayoutOrder = buttonIndex * 2 - 2,
					Size = layout.ToolbarDividerSize,
					Visible = shown,
				})
			end

			children[`button{buttonIndex}`] = createElement(IconButton, {
				icon = if useMutedIcon then button.mutedIcon :: string else button.icon,
				iconSize = tokens.IconSize.Large,
				onActivated = function()
					group.onPress(buttonIndex)
				end,
				native = {
					BackgroundTransparency = 1,
					LayoutOrder = buttonIndex * 2 - 1,
					Size = tokens.ToolbarButtonSize,
					Visible = shown,
				},
			})
		end

		local background = if group.selected then tokens.Shift_300 else nil

		groups[group.key] = createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = if background then background.Color3 else nil,
			BackgroundTransparency = if background then background.Transparency else 1,
			BorderSizePixel = 0,
			LayoutOrder = groupIndex,
			Visible = group.visible ~= false,
		}, children)
	end

	return createElement("Frame", {
		AnchorPoint = layout.ToolbarAnchorPoint,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = tokens.Surface_100.Color3,
		BackgroundTransparency = tokens.Surface_100.Transparency,
		BorderSizePixel = 0,
		Position = layout.ToolbarPosition,
	}, groups)
end)

return Toolbar

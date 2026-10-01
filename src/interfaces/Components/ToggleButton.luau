local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local React = require(ReplicatedStorage.Packages.React)

local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo
local useState = React.useState

export type ToggleButtonProps = {
	label: string,
	initialOn: boolean?,
	onToggle: (isOn: boolean) -> (),
	layoutOrder: number?,
	alignLeft: boolean?,
}

--[=[
	@class ToggleButton
	@client

	A labelled on/off pill, right-aligned in its row unless `alignLeft` hugs it to the left. It owns
	its on state and reports each flip through `onToggle`.
]=]
local ToggleButton = memo(function(props: ToggleButtonProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local labelFont = theme.fonts.ToolTitleFont
	local isOn, setIsOn = useState(props.initialOn == true)

	return createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		Size = if props.alignLeft then UDim2.fromScale(0, 0) else UDim2.fromScale(1, 0),
	}, {
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = if props.alignLeft
				then Enum.HorizontalAlignment.Left
				else Enum.HorizontalAlignment.Right,
			ItemLineAlignment = Enum.ItemLineAlignment.Center,
			Padding = tokens.Padding.Small,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		pill = createElement("ImageButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = if isOn then CreationIcons.uiImages.ToggleOn else CreationIcons.uiImages.ToggleOff,
			LayoutOrder = 1,
			Size = tokens.TogglePillSize,
			[React.Event.Activated] = function()
				setIsOn(not isOn)
				props.onToggle(not isOn)
			end,
		}),
		label = createElement("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = labelFont.Font,
			LayoutOrder = 2,
			Text = props.label,
			TextColor3 = tokens.Colors.ContentDefault,
			TextSize = labelFont.FontSize,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end)

return ToggleButton

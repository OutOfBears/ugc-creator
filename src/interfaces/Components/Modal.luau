local GamepadService = game:GetService("GamepadService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)

local Button = require("./Button")
local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement
local memo = React.memo
local useEffect = React.useEffect

export type ModalButton = {
	text: string,
	onActivated: () -> (),
}

export type ModalProps = {
	title: string,
	body: string,
	buttons: { ModalButton },
}

--[=[
	@class Modal
	@client

	A centered dialog over a dimming overlay: title, body and a row of buttons, the first
	emphasised. Mounting it turns on the gamepad cursor for gamepad players, who otherwise could
	not reach its buttons.
]=]
local Modal = memo(function(props: ModalProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local fonts = theme.fonts

	useEffect(function()
		if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
			GamepadService:EnableGamepadCursor(nil)
		end
	end, {})

	local buttons: { [string]: any } = {
		listLayout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			Padding = tokens.Padding.Small,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, button in props.buttons do
		buttons[`button{index}`] = createElement(Button, {
			emphasis = index == 1,
			text = button.text,
			onActivated = button.onActivated,
			native = { LayoutOrder = index },
		})
	end

	local function text(layoutOrder: number, value: string, font: any, color: Color3)
		return createElement("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = font.Font,
			LayoutOrder = layoutOrder,
			Size = UDim2.fromScale(1, 0),
			Text = value,
			TextColor3 = color,
			TextSize = font.FontSize,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	return createElement(React.Fragment, nil, {
		overlay = createElement("TextButton", {
			Active = false,
			AutoButtonColor = false,
			BackgroundColor3 = tokens.Shadow.Color3,
			BackgroundTransparency = tokens.Shadow.Transparency,
			BorderSizePixel = 0,
			Selectable = false,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 1,
		}),
		modal = createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = tokens.Surface_100.Color3,
			BackgroundTransparency = tokens.Surface_100.Transparency,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = if #props.buttons <= 2 then tokens.ModalTwoButtonSize else tokens.ModalThreeButtonSize,
			ZIndex = 10,
		}, {
			corner = createElement("UICorner", {
				CornerRadius = tokens.Radius.Large,
			}),
			padding = createElement("UIPadding", {
				PaddingBottom = tokens.Padding.XLarge,
				PaddingLeft = tokens.Padding.XLarge,
				PaddingRight = tokens.Padding.XLarge,
				PaddingTop = tokens.Padding.XLarge,
			}),
			stroke = createElement("UIStroke", {
				Color = tokens.Stroke_Muted.Color,
				Thickness = tokens.Stroke_Muted.Thickness,
				Transparency = tokens.Stroke_Muted.Transparency,
			}),
			listLayout = createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = tokens.Padding.XLarge,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			textContainer = createElement("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
			}, {
				listLayout = createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = tokens.Padding.XSmall,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				padding = createElement("UIPadding", {
					PaddingRight = tokens.Padding.XXLarge,
				}),
				title = text(1, props.title, fonts.ModalTitleFont, tokens.Colors.ContentEmphasis),
				body = text(2, props.body, fonts.ModalBodyFont, tokens.Colors.ContentDefault),
			}),
			buttonContainer = createElement("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
			}, buttons),
		}),
	})
end)

return Modal

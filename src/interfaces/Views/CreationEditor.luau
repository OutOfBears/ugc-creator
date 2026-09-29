local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local React = require(ReplicatedStorage.Packages.React)

local Button = require("../Components/Button")
local SessionGate = require("./Creation/SessionGate")
local useAtom = require("../Hooks/useAtom")
local useCreationSession = require("../Hooks/useCreationSession")
local useScreenGui = require("../Hooks/useScreenGui")
local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement

export type CreationEditorProps = {
	playerGui: ScreenGui,
}

local function Editor(props: CreationEditorProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local buyFont = theme.fonts.BuyButtonFont

	local session = useCreationSession()
	local activeTool = useAtom(session.panels.activeTool)
	local isPanelOpen = session.panels:isPanelOpen(activeTool)

	useScreenGui(props.playerGui, {
		DisplayOrder = 5,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	})

	local price = session.modelInfo:getCreationPrice()

	return createElement(React.Fragment, nil, {
		padding = createElement("UIPadding", {
			PaddingBottom = tokens.Padding.XXLarge,
			PaddingRight = theme.layout.LocalMenuRightPadding,
		}),
		buyButton = createElement(Button, {
			emphasis = true,
			text = if price > 0 then `{CreationStrings.robuxIcon} {price}` else CreationStrings.publishButton,
			onActivated = function()
				session:publish()
			end,
			native = {
				AnchorPoint = Vector2.new(1, 1),
				FontFace = buyFont.Font,
				Position = UDim2.fromScale(1, 1),
				Size = tokens.BuyButtonSize,
				TextSize = buyFont.FontSize,
				Visible = not isPanelOpen or theme.layout.CoreUIVisibilityWithPanel,
			},
		}),
	})
end

--[=[
	@class CreationEditor
	@client

	The editor's buy/publish button, bottom right. It steps aside while a panel is open on layouts
	where the panel covers it.
]=]
local function CreationEditor(props: CreationEditorProps)
	return createElement(SessionGate, nil, {
		editor = createElement(Editor, props),
	})
end

return CreationEditor

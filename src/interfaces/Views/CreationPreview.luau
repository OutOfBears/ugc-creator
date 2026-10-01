local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local React = require(ReplicatedStorage.Packages.React)

local SegmentedControl = require("../Components/SegmentedControl")
local SessionGate = require("./Creation/SessionGate")
local useAtom = require("../Hooks/useAtom")
local useCreationSession = require("../Hooks/useCreationSession")
local useScreenGui = require("../Hooks/useScreenGui")
local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement

export type CreationPreviewProps = {
	playerGui: ScreenGui,
}

local function Preview(props: CreationPreviewProps)
	local theme = useTheme()
	local tokens = theme.tokens
	local isConsole = GuiService:IsTenFootInterface()

	local session = useCreationSession()
	local screen = useAtom(session.screen)
	local previewTarget = useAtom(session.previewTarget)

	useScreenGui(props.playerGui, {
		DisplayOrder = 5,
		Enabled = screen == "preview",
		ScreenInsets = if isConsole then Enum.ScreenInsets.None else Enum.ScreenInsets.CoreUISafeInsets,
	})

	if not session.previewTool then
		return nil
	end

	return createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, {
		padding = createElement("UIPadding", {
			PaddingBottom = tokens.Padding.XXLarge,
			PaddingLeft = tokens.Padding.XXLarge,
			PaddingRight = tokens.Padding.XXLarge,
			PaddingTop = if isConsole then tokens.Padding.Medium + tokens.TopBarHeight else tokens.Padding.Medium,
		}),
		switcher = createElement(SegmentedControl, {
			options = CreationStrings.previewTargets,
			selectedIndex = previewTarget,
			onSelect = function(index: number)
				session:setPreviewTarget(index)
			end,
			native = {
				AnchorPoint = theme.layout.AvatarPreviewAnchorPoint,
				Position = theme.layout.AvatarPreviewPosition,
			},
		}),
	})
end

--[=[
	@class CreationPreview
	@client

	The avatar preview's switcher between the stock avatar and the player's own. Accessories only.
]=]
local function CreationPreview(props: CreationPreviewProps)
	return createElement(SessionGate, nil, {
		preview = createElement(Preview, props),
	})
end

return CreationPreview

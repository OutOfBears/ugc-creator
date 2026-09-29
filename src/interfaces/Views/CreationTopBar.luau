local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local React = require(ReplicatedStorage.Packages.React)

local LocalMenu = require("../Components/LocalMenu")
local SessionGate = require("./Creation/SessionGate")
local useAtom = require("../Hooks/useAtom")
local useCreationSession = require("../Hooks/useCreationSession")
local useScreenGui = require("../Hooks/useScreenGui")
local useTheme = require("../Hooks/useTheme")

local createElement = React.createElement

export type CreationTopBarProps = {
	playerGui: ScreenGui,
}

local function TopBar(props: CreationTopBarProps)
	local theme = useTheme()

	local session = useCreationSession()
	local screen = useAtom(session.screen)
	local activeTool = useAtom(session.panels.activeTool)
	local isPanelOpen = session.panels:isPanelOpen(activeTool)

	useScreenGui(props.playerGui, {
		ScreenInsets = if GuiService:IsTenFootInterface()
			then Enum.ScreenInsets.None
			else Enum.ScreenInsets.TopbarSafeInsets,
	})

	local exitButton = {
		icon = CreationIcons.icons.ExitEditor,
		onActivated = function()
			session:quit()
		end,
	}

	local editorGroups = {
		{
			{
				icon = CreationIcons.icons.ResetChanges,
				onActivated = function()
					session.modal("resetEdits")
				end,
			},
		},
		{ exitButton },
	}

	local hasPreview = session:getCreationType() == CreationConfig.creationTypes.accessory
	local previewMenu = nil
	if hasPreview then
		table.insert(editorGroups, 2, {
			{
				icon = CreationIcons.icons.AvatarPreview,
				onActivated = function()
					session:openAvatarPreview()
				end,
			},
		})

		previewMenu = createElement(LocalMenu, {
			visible = screen == "preview",
			groups = {
				{
					{
						icon = CreationIcons.editorIcons[session.modelInfo:getBlankName()],
						onActivated = function()
							session:returnToEditor()
						end,
					},
				},
				{ exitButton },
			},
		})
	end

	return createElement(React.Fragment, nil, {
		editorMenu = createElement(LocalMenu, {
			visible = screen == "edit" and (not isPanelOpen or theme.layout.CoreUIVisibilityWithPanel),
			groups = editorGroups,
		}),
		previewMenu = previewMenu,
	})
end

--[=[
	@class CreationTopBar
	@client

	The editor's top bar: reset, exit, and on accessories the buttons that swap between the editor
	and the avatar preview. The editor menu steps aside while a panel is open on layouts where the
	panel covers it.
]=]
local function CreationTopBar(props: CreationTopBarProps)
	return createElement(SessionGate, nil, {
		topBar = createElement(TopBar, props),
	})
end

return CreationTopBar

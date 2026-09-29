local GamepadService = game:GetService("GamepadService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ClientAtoms = require(ReplicatedStorage.Client.Modules.ClientAtoms)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local React = require(ReplicatedStorage.Packages.React)

local Modal = require("../Components/Modal")
local ThemeContext = require("../Contexts/ThemeContext")
local useAtom = require("../Hooks/useAtom")
local useScreenGui = require("../Hooks/useScreenGui")

local createElement = React.createElement

export type SwitchEditorsModalProps = {
	playerGui: ScreenGui,
}

--[=[
	@class SwitchEditorsModal
	@client

	Warns that starting a different creation discards the current one, offering to publish,
	continue or back out. Shown from `ClientAtoms.switchEditorsPrompt`, before any new session
	exists. It dismisses itself before running the chosen callback, so a slow callback cannot leave
	it on screen.
]=]
local function SwitchEditorsModal(props: SwitchEditorsModalProps)
	local prompt = useAtom(ClientAtoms.switchEditorsPrompt)
	local isMobile = useAtom(ClientAtoms.isMobile)

	useScreenGui(props.playerGui, {
		DisplayOrder = 100,
		Enabled = prompt ~= nil,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
	})

	if not prompt then
		return nil
	end

	local function choose(callback: () -> ())
		return function()
			ClientAtoms.switchEditorsPrompt(nil)
			if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
				GamepadService:DisableGamepadCursor(nil)
			end

			callback()
		end
	end

	local price = prompt.creationPrice

	return createElement(ThemeContext.Provider, {
		isMobile = isMobile,
	}, {
		modal = createElement(Modal, {
			title = CreationStrings.editorSwitchTitle,
			body = CreationStrings.editorSwitchBody,
			buttons = {
				{
					text = if price > 0 then `{CreationStrings.robuxIcon} {price}` else CreationStrings.publishButton,
					onActivated = choose(prompt.onBuy),
				},
				{ text = CreationStrings.modalButtons.continue, onActivated = choose(prompt.onContinue) },
				{ text = CreationStrings.modalButtons.cancel, onActivated = choose(prompt.onCancel) },
			},
		}),
	})
end

return SwitchEditorsModal

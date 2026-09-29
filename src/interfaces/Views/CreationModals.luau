local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local React = require(ReplicatedStorage.Packages.React)

local Modal = require("../Components/Modal")
local SessionGate = require("./Creation/SessionGate")
local useAtom = require("../Hooks/useAtom")
local useCreationSession = require("../Hooks/useCreationSession")
local useScreenGui = require("../Hooks/useScreenGui")

local createElement = React.createElement

export type CreationModalsProps = {
	playerGui: ScreenGui,
}

local function Modals(props: CreationModalsProps)
	local session = useCreationSession()
	local modal = useAtom(session.modal)

	useScreenGui(props.playerGui, {
		DisplayOrder = 100,
		Enabled = modal ~= nil,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
	})

	local function close()
		session.modal(nil)
	end

	if modal == "resetEdits" then
		return createElement(Modal, {
			title = CreationStrings.resetEditsTitle,
			body = CreationStrings.resetEditsBody,
			buttons = {
				{
					text = CreationStrings.modalButtons.ok,
					onActivated = function()
						close()
						session:resetModelInfo()
					end,
				},
				{ text = CreationStrings.modalButtons.cancel, onActivated = close },
			},
		})
	elseif modal == "accessoryAdjustment" then
		return createElement(Modal, {
			title = CreationStrings.accessoryAdjustmentTitle,
			body = CreationStrings.accessoryAdjustmentBody,
			buttons = {
				{ text = CreationStrings.modalButtons.ok, onActivated = close },
			},
		})
	end

	return nil
end

--[=[
	@class CreationModals
	@client

	The editor's confirmation dialogs — resetting every edit, and the one-time accessory fit
	warning — driven by the session's `modal`.
]=]
local function CreationModals(props: CreationModalsProps)
	return createElement(SessionGate, nil, {
		modals = createElement(Modals, props),
	})
end

return CreationModals

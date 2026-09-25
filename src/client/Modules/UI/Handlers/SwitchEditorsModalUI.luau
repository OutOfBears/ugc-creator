local GamepadService = game:GetService("GamepadService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local Modal = require("../Components/Modal")
local Overlay = require("../Components/Overlay")

local player = Players.LocalPlayer

export type SwitchEditorsModalUI = {
	-- vars
	screenGui: ScreenGui,
	-- methods
	destroy: (self: SwitchEditorsModalUI) -> (),
}

--[=[
	@class SwitchEditorsModalUI
	@client

	Warns that starting a different creation discards the current one, offering to publish,
	continue, or back out.

	Unlike the other handlers this one is built by [CreationController] before any editor exists,
	so it takes the [StyleSheet] rather than reading one off [BaseUI], and brings its own
	ScreenGui. It tears itself down as soon as a button is pressed — before the callback runs, so
	a slow callback cannot leave it on screen.
]=]
local function SwitchEditorsModalUI(
	style: any,
	creationPrice: number,
	onBuy: () -> (),
	onContinue: () -> (),
	onCancel: () -> ()
): SwitchEditorsModalUI
	local object = {} :: SwitchEditorsModalUI
	local playerGui = player:WaitForChild("PlayerGui")

	object.screenGui = Create("ScreenGui", {
		Name = "ModalUI",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		Parent = playerGui,
	}) :: ScreenGui

	style:linkGui(object.screenGui)

	local overlay = Overlay()
	overlay.Parent = object.screenGui

	local buyButtonText = if creationPrice > 0
		then `{CreationStrings.robuxIcon} {creationPrice}`
		else CreationStrings.publishButton

	local buttonInfos = {
		{
			text = buyButtonText,
			callback = function()
				object:destroy()
				onBuy()
			end,
		},
		{
			text = "Continue",
			callback = function()
				object:destroy()
				onContinue()
			end,
		},
		{
			text = "Cancel",
			callback = function()
				object:destroy()
				onCancel()
			end,
		},
	}

	local modal = Modal(CreationStrings.editorSwitchTitle, CreationStrings.editorSwitchBody, buttonInfos)
	modal.Parent = object.screenGui

	function object:destroy()
		if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
			GamepadService:DisableGamepadCursor(nil)
		end

		self.screenGui:Destroy()
	end

	return object
end

return SwitchEditorsModalUI

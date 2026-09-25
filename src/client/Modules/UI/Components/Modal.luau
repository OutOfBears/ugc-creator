local GamepadService = game:GetService("GamepadService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local StyleConsts = require("../Style/StyleConsts")
local StyleTokens = require(ReplicatedStorage.Shared.Data.StyleTokens)
local StyleUtils = require("../Style/StyleUtils")
local TextButton = require("./TextButton")

--[=[
	@class Modal
	@client

	Generic modal with a title, a body, and at least one button. The leftmost button is emphasised.
	Constructing one enables the gamepad cursor when the player is on a gamepad, since a modal is
	otherwise unreachable there.

	@param titleString string -- the modal title
	@param bodyString string -- the modal body copy
	@param buttonInfos { TextButton.ButtonInfo } -- buttons in left-to-right order
	@return Frame -- the modal frame
]=]
local function Modal(titleString: string, bodyString: string, buttonInfos: { TextButton.ButtonInfo }): Frame
	local modalFrame = Create("Frame", {
		Name = "ModalFrame",
		Size = if #buttonInfos <= 2
			then StyleTokens.style.ModalTwoButtonSize
			else StyleTokens.style.ModalThreeButtonSize,
		Tags = { StyleConsts.tags.ModalFrame },
	}) :: Frame

	Create("Frame", {
		Name = "TextContainer",
		LayoutOrder = 1,
		Tags = { StyleConsts.tags.ModalTextFrame },
		Children = {
			Create("TextLabel", {
				Name = "TitleText",
				Text = titleString,
				LayoutOrder = 1,
				Tags = { StyleConsts.tags.ModalTitle },
			}),
			Create("TextLabel", {
				Name = "BodyText",
				Text = bodyString,
				LayoutOrder = 2,
				Tags = { StyleConsts.tags.ModalBody },
			}),
		},
		Parent = modalFrame,
	})

	local buttonFrame = Create("Frame", {
		Name = "ButtonContainer",
		LayoutOrder = 2,
		Tags = { StyleConsts.tags.ButtonFrame },
		Parent = modalFrame,
	})

	for i, buttonInfo in buttonInfos do
		local button = TextButton(buttonInfo)
		button.LayoutOrder = i

		if i == 1 then
			StyleUtils.addStyleTag(button, StyleConsts.tags.EmphasisButton)
		end

		button.Parent = buttonFrame
	end

	if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
		GamepadService:EnableGamepadCursor(nil)
	end

	return modalFrame
end

return Modal

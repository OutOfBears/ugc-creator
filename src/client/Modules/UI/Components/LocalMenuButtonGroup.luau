local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local IconButton = require("./IconButton")
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")

export type LocalMenuButtonGroupInfo = { IconButton.IconButtonInfo }

--[=[
	@class LocalMenuButtonGroup
	@client

	One pill of grouped buttons in the local menu. Layout orders are spaced by two so a caller can
	slot content between buttons.

	@param localMenuButtonGroupInfo LocalMenuButtonGroupInfo -- the buttons, in display order
	@return Frame -- the button group frame
]=]
local function LocalMenuButtonGroup(localMenuButtonGroupInfo: LocalMenuButtonGroupInfo): Frame
	local localMenuButtonGroup = Create("Frame", {
		Name = "LocalMenuButtonGroup",
		Tags = { StyleConsts.tags.LocalMenuButtonGroup },
	}) :: Frame

	for i, buttonInfo in localMenuButtonGroupInfo do
		local button = IconButton(buttonInfo.iconId, buttonInfo.callback)
		button.LayoutOrder = i * 2
		StyleUtils.addStyleTag(button, StyleConsts.tags.LocalMenuButton)
		button.Parent = localMenuButtonGroup
	end

	return localMenuButtonGroup
end

return LocalMenuButtonGroup

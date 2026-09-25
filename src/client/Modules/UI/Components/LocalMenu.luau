local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local LocalMenuButtonGroup = require("./LocalMenuButtonGroup")
local StyleConsts = require("../Style/StyleConsts")

--[=[
	@class LocalMenu
	@client

	The menu of general editing controls — reset, preview, exit — sitting at the top of the screen.
	On a ten-foot interface it takes the `LocalMenuConsole` tag instead, which moves it clear of the
	console safe area.

	@param localMenuButtonGroupInfos { LocalMenuButtonGroup.LocalMenuButtonGroupInfo } -- groups in display order
	@return Frame -- the local menu frame
]=]
local function LocalMenu(localMenuButtonGroupInfos: { LocalMenuButtonGroup.LocalMenuButtonGroupInfo }): Frame
	local tag = if GuiService:IsTenFootInterface()
		then StyleConsts.tags.LocalMenuConsole
		else StyleConsts.tags.LocalMenu

	local localMenu = Create("Frame", {
		Name = "LocalMenu",
		Tags = { tag },
	}) :: Frame

	for i, buttonGroupInfo in localMenuButtonGroupInfos do
		local buttonGroup = LocalMenuButtonGroup(buttonGroupInfo)
		buttonGroup.LayoutOrder = i
		buttonGroup.Parent = localMenu
	end

	return localMenu
end

return LocalMenu

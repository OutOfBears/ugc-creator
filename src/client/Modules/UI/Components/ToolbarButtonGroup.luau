local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Divider = require("./ToolbarGroupDivider")
local IconButton = require("./IconButton")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")

export type ToolbarButtonInfo = {
	iconId: string,
	mutedIconId: string?,
	callback: () -> (),
}

export type ToolbarButtonGroupInfo = { ToolbarButtonInfo }

export type ChildButtonIcon = {
	imageLabel: ImageLabel,
	iconId: string,
	mutedIconId: string?,
}

export type ToolbarButtonGroup = {
	-- vars
	frame: Frame,
	children: { GuiObject },
	childButtonIcons: { ChildButtonIcon },
	currentSelection: number?,
	maid: Maid.Maid,
	-- methods
	hideExpanded: (self: ToolbarButtonGroup) -> (),
	unhideAll: (self: ToolbarButtonGroup) -> (),
	changeSelection: (self: ToolbarButtonGroup, i: number?) -> (),
	destroy: (self: ToolbarButtonGroup) -> (),
}

--[=[
	@class ToolbarButtonGroup
	@client

	A group of one or more toolbar buttons. Only the first is visible until the group is expanded;
	the rest fan out behind dividers. Pressing the already-selected button runs `reselectCallback`
	instead of the button's own callback, which is how a tool re-opens its panel.

	@param toolbarButtonGroupInfo ToolbarButtonGroupInfo -- buttons in display order; the first is the group's primary
	@param reselectCallback () -> () -- fired when the selected button is pressed again
	@return ToolbarButtonGroup
]=]
local function ToolbarButtonGroup(
	toolbarButtonGroupInfo: ToolbarButtonGroupInfo,
	reselectCallback: () -> ()
): ToolbarButtonGroup
	local maid = Maid.new()
	local object = {} :: ToolbarButtonGroup

	object.maid = maid
	object.currentSelection = nil
	object.children = {}
	object.childButtonIcons = {}

	object.frame = maid:add(Create("Frame", {
		Name = "ToolbarButtonGroup",
		Tags = { StyleConsts.tags.ToolbarButtonGroup },
	}) :: Frame)

	--[=[
		@within ToolbarButtonGroup
		@param i number? -- the button to select; without one the primary icon is restored
	]=]
	function object:changeSelection(i: number?)
		if self.currentSelection and self.currentSelection ~= i then
			local currentButtonIcon = self.childButtonIcons[self.currentSelection]
			if currentButtonIcon.mutedIconId then
				currentButtonIcon.imageLabel.Image = currentButtonIcon.mutedIconId
			end

			local newButtonIcon = if i then self.childButtonIcons[i] else self.childButtonIcons[1]
			newButtonIcon.imageLabel.Image = newButtonIcon.iconId
		end

		self.currentSelection = i
	end

	--[=[
		@within ToolbarButtonGroup

		Collapses the group back to its primary button.
	]=]
	function object:hideExpanded()
		for i = 2, #self.children do
			StyleUtils.addStyleTag(self.children[i], StyleConsts.tags.Hidden)
		end

		self:changeSelection()
	end

	--[=[
		@within ToolbarButtonGroup

		Expands the group so every button and divider is visible.
	]=]
	function object:unhideAll()
		for _, child in self.children do
			StyleUtils.removeStyleTag(child, StyleConsts.tags.Hidden)
		end
	end

	function object:destroy()
		maid:doCleaning()
	end

	for i, buttonInfo in toolbarButtonGroupInfo do
		local button

		local buttonCallback = function()
			if object.currentSelection == i then
				reselectCallback()
			else
				object:changeSelection(i)
				buttonInfo.callback()
			end
		end

		if i == 1 then
			button = IconButton(buttonInfo.iconId, function()
				if object.currentSelection ~= i then
					object:unhideAll()
				end

				buttonCallback()
			end)
		else
			table.insert(object.children, Divider())

			local icon = if buttonInfo.mutedIconId then buttonInfo.mutedIconId else buttonInfo.iconId
			button = IconButton(icon, buttonCallback)
		end

		StyleUtils.addStyleTag(button, StyleConsts.tags.ToolbarButton)
		table.insert(object.children, button)
		table.insert(object.childButtonIcons, {
			imageLabel = button:FindFirstChildOfClass("ImageLabel") :: ImageLabel,
			iconId = buttonInfo.iconId,
			mutedIconId = buttonInfo.mutedIconId,
		})
	end

	for i, child in object.children do
		child.LayoutOrder = i
		child.Parent = object.frame
	end

	object:hideExpanded()

	return object
end

return ToolbarButtonGroup

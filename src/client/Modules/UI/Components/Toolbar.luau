local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")
local ToolbarButtonGroup = require("./ToolbarButtonGroup")

export type Toolbar = {
	-- vars
	frame: Frame,
	buttonGroups: { ToolbarButtonGroup.ToolbarButtonGroup },
	currentSelection: number?,
	maid: Maid.Maid,
	-- methods
	getFrame: (self: Toolbar) -> Frame,
	makeSelection: (self: Toolbar, i: number) -> (),
	removeSelection: (self: Toolbar) -> (),
	destroy: (self: Toolbar) -> (),
}

--[=[
	@class Toolbar
	@client

	Single-selection toolbar of [ToolbarButtonGroup]s, in left-to-right display order. Nothing is
	selected until a group's primary button is pressed. The constructor rewrites the primary button
	of each group so pressing it also drives the toolbar's selection.

	@param toolbarButtonGroupInfos { ToolbarButtonGroup.ToolbarButtonGroupInfo } -- groups in display order
	@param reselectCallback () -> () -- fired when an already-selected button is pressed again
	@return Toolbar
]=]
local function Toolbar(
	toolbarButtonGroupInfos: { ToolbarButtonGroup.ToolbarButtonGroupInfo },
	reselectCallback: () -> ()
): Toolbar
	local maid = Maid.new()
	local object = {} :: Toolbar

	object.maid = maid
	object.currentSelection = nil
	object.buttonGroups = {}

	object.frame = maid:add(Create("Frame", {
		Name = "Toolbar",
		Tags = { StyleConsts.tags.Toolbar },
	}) :: Frame)

	--[=[
		@within Toolbar
		@return Frame -- the toolbar frame, for parenting into a layout
	]=]
	function object:getFrame(): Frame
		return self.frame
	end

	--[=[
		@within Toolbar
		@param i number -- the group to select, collapsing whichever group was selected before
	]=]
	function object:makeSelection(i: number)
		if self.currentSelection and self.currentSelection ~= i then
			local currentButtonGroup = self.buttonGroups[self.currentSelection]
			currentButtonGroup:hideExpanded()
			StyleUtils.removeStyleTag(currentButtonGroup.frame, StyleConsts.tags.ButtonSelected)
		end

		self.currentSelection = i
		StyleUtils.addStyleTag(self.buttonGroups[i].frame, StyleConsts.tags.ButtonSelected)
	end

	--[=[
		@within Toolbar

		Collapses and deselects the selected group, leaving the toolbar with no selection.
	]=]
	function object:removeSelection()
		if self.currentSelection then
			local currentButtonGroup = self.buttonGroups[self.currentSelection]
			currentButtonGroup:hideExpanded()
			StyleUtils.removeStyleTag(currentButtonGroup.frame, StyleConsts.tags.ButtonSelected)
			self.currentSelection = nil
		end
	end

	function object:destroy()
		maid:doCleaning()
	end

	for i, toolbarButtonGroupInfo in toolbarButtonGroupInfos do
		local primaryButtonCallback = toolbarButtonGroupInfo[1].callback
		toolbarButtonGroupInfo[1] = {
			iconId = toolbarButtonGroupInfo[1].iconId,
			mutedIconId = toolbarButtonGroupInfo[1].mutedIconId,
			callback = function()
				object:makeSelection(i)
				primaryButtonCallback()
			end,
		}

		local toolbarButtonGroup = maid:add(ToolbarButtonGroup(toolbarButtonGroupInfo, reselectCallback))
		table.insert(object.buttonGroups, toolbarButtonGroup)

		toolbarButtonGroup.frame.LayoutOrder = i
		toolbarButtonGroup.frame.Parent = object.frame
	end

	return object
end

return Toolbar

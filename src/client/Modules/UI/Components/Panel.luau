local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local IconButton = require("./IconButton")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")

export type Panel = {
	-- vars
	frame: Frame,
	maid: Maid.Maid,
	-- methods
	destroy: (self: Panel) -> (),
}

local function createHeaderBar(title: string, onClose: () -> (), onTrash: () -> ()): Instance
	local headerBar = Create("Frame", {
		Name = "PanelHeaderBar",
		Tags = { StyleConsts.tags.PanelHeader },
		Children = {
			Create("TextLabel", {
				Name = "TitleLabel",
				Text = title,
			}),
		},
	})

	local iconsFrame = Create("Frame", {
		Name = "IconFrame",
		Parent = headerBar,
	})

	local trashButton = IconButton(CreationIcons.icons.Delete, onTrash)
	trashButton.LayoutOrder = 3
	StyleUtils.addStyleTag(trashButton, StyleConsts.tags.MediumIconButton)
	trashButton.Parent = iconsFrame

	local closeButton = IconButton(CreationIcons.icons.XButton, onClose)
	closeButton.LayoutOrder = 4
	StyleUtils.addStyleTag(closeButton, StyleConsts.tags.MediumIconButton)
	closeButton.Parent = iconsFrame

	return headerBar
end

--[=[
	@class Panel
	@client

	A side panel housing the texture and mesh editing tools. Its size, corner radius and anchoring
	all come from theme tokens, so the same panel restyles itself between mobile and desktop.

	@param title string -- header text
	@param onClose () -> () -- fired by the header's close button
	@param onTrash () -> () -- fired by the header's delete button
	@param toolFrames { GuiObject } -- tool frames to stack in the panel body, in display order
	@return Panel
]=]
local function Panel(title: string, onClose: () -> (), onTrash: () -> (), toolFrames: { GuiObject }): Panel
	local maid = Maid.new()
	local object = {} :: Panel

	object.maid = maid

	object.frame = maid:add(Create("Frame", {
		Name = "Panel",
		Tags = { StyleConsts.tags.Panel },
		Children = { createHeaderBar(title, onClose, onTrash) },
	}) :: Frame)

	local toolsContainer = Create("Frame", {
		Name = "ToolsContainer",
		Tags = { StyleConsts.tags.PanelToolsContainer },
		Parent = object.frame,
	})

	for i, tool in toolFrames do
		tool.LayoutOrder = i
		tool.Parent = toolsContainer
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return Panel

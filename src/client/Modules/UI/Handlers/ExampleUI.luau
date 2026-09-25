local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local HorizontalPillbar = require("../Components/HorizontalPillbar")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Panel = require("../Components/Panel")
local StyleConsts = require("../Style/StyleConsts")
local StyleSheet = require("../Style/StyleSheet")
local ToolFrame = require("../Components/ToolFrame")
local Toolbar = require("../Components/Toolbar")

local player = Players.LocalPlayer

export type ExampleUI = {
	-- vars
	screenGui: ScreenGui,
	style: StyleSheet.Style,
	toolbar: Toolbar.Toolbar,
	panel: Panel.Panel,
	maid: Maid.Maid,
	-- methods
	destroy: (self: ExampleUI) -> (),
}

--[=[
	@class ExampleUI
	@client

	A portable template showing how to build a handler with the Style system and components. It
	is not live UI — nothing in the experience constructs it, and it is kept only as a starting
	point for new handlers.

	To try it, require this module from a client script and call `ExampleUI()`.
]=]
local function ExampleUI(): ExampleUI
	local maid = Maid.new()
	local object = {} :: ExampleUI
	local playerGui = player:WaitForChild("PlayerGui")

	object.maid = maid

	-- Optional, but useful when the UI is designed for one orientation.
	local previousScreenOrientation = playerGui.ScreenOrientation
	playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight

	object.screenGui = maid:add(Create("ScreenGui", {
		Name = "EditingUI",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		Parent = playerGui,
	})) :: ScreenGui

	object.style = maid:add(StyleSheet())
	object.style:linkGui(object.screenGui)

	-- These styled partitions position the toolbar and panel and adapt them to different screen
	-- sizes. Tag your own frames instead if you want to place the components yourself.
	local frame = Create("Frame", {
		Name = "UIParent",
		Tags = { StyleConsts.tags.UIParent },
		Parent = object.screenGui,
	})

	local toolbarParent = Create("Frame", {
		Name = "ToolbarParent",
		Tags = { StyleConsts.tags.ToolbarParent },
		Parent = frame,
	})

	local panelParent = Create("Frame", {
		Name = "PanelParent",
		Tags = { StyleConsts.tags.PanelParent },
		Parent = frame,
	})

	local function setupToolbar()
		-- Grouped buttons read better with a muted icon for the unselected state, but it is optional.
		local group1 = {
			{
				iconId = CreationIcons.icons.Pattern,
				mutedIconId = CreationIcons.icons.PatternMuted,
				callback = function()
					print("Toolbar group 1 button 1 clicked")
				end,
			},
			{
				iconId = CreationIcons.icons.Pattern,
				mutedIconId = CreationIcons.icons.PatternMuted,
				callback = function()
					print("Toolbar group 1 button 2 clicked")
				end,
			},
		}
		local group2 = {
			{
				iconId = CreationIcons.icons.Pattern,
				callback = function()
					print("Toolbar group 2 button 1 clicked")
				end,
			},
		}
		local group3 = {
			{
				iconId = CreationIcons.icons.Pattern,
				mutedIconId = CreationIcons.icons.PatternMuted,
				callback = function()
					print("Toolbar group 3 button 1 clicked")
				end,
			},
			{
				iconId = CreationIcons.icons.Pattern,
				mutedIconId = CreationIcons.icons.PatternMuted,
				callback = function()
					print("Toolbar group 3 button 2 clicked")
				end,
			},
			{
				iconId = CreationIcons.icons.Pattern,
				mutedIconId = CreationIcons.icons.PatternMuted,
				callback = function()
					print("Toolbar group 3 button 3 clicked")
				end,
			},
			{
				iconId = CreationIcons.icons.Pattern,
				mutedIconId = CreationIcons.icons.PatternMuted,
				callback = function()
					print("Toolbar group 3 button 4 clicked")
				end,
			},
		}

		local toolbarGroups = {
			group1,
			group2,
			group3,
		}

		object.toolbar = maid:add(Toolbar(toolbarGroups, function()
			object.toolbar:removeSelection()
		end))

		-- A component that tracks state returns an object, so reach through it for the frame.
		-- Stateless components return the instance itself.
		object.toolbar:getFrame().Parent = toolbarParent
	end

	local function setupPanel()
		local pillbarButtonStack = {
			{
				iconId = CreationIcons.icons.Pattern,
				callback = function()
					print("Pillbar button 1 clicked")
				end,
			},
			{
				iconId = CreationIcons.icons.Pattern,
				callback = function()
					print("Pillbar button 2 clicked")
				end,
			},
		}
		local pillbar = maid:add(HorizontalPillbar(pillbarButtonStack))

		-- A tool frame adds a title and padding. Components do not have to live in one.
		local pillbarToolFrame = ToolFrame(pillbar.frame, "Pillbar Tool")

		local onClosePanelCallback = function()
			print("Panel Close button clicked")
		end
		local onDeleteCallback = function()
			print("Panel Delete button clicked")
		end

		object.panel = maid:add(Panel("Example Panel", onClosePanelCallback, onDeleteCallback, { pillbarToolFrame }))
		object.panel.frame.Parent = panelParent
		object.panel.frame.Name = "ExamplePanel"
	end

	setupToolbar()
	setupPanel()

	function object:destroy()
		maid:doCleaning()

		playerGui.ScreenOrientation = previousScreenOrientation
	end

	return object
end

return ExampleUI

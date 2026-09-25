local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local SegmentedControl = require("../Components/SegmentedControl")
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")

local player = Players.LocalPlayer

export type PreviewUI = {
	-- vars
	baseUI: any,
	session: any,
	previewTool: any,
	style: any,
	hasSeenAccessoryAdjustmentModal: boolean,
	currentSelection: number,
	screenGui: ScreenGui,
	frame: Frame,
	switcher: SegmentedControl.SegmentedControl,
	maid: Maid.Maid,
	-- methods
	show: (self: PreviewUI) -> (),
	hide: (self: PreviewUI) -> (),
	destroy: (self: PreviewUI) -> (),
}

--[=[
	@class PreviewUI
	@client

	The avatar preview's switcher between the stock avatar and the player's own. Owned by
	[BaseUI], and only reachable on accessories.
]=]
local function PreviewUI(baseUI: any, session: any, previewTool: any): PreviewUI
	local maid = Maid.new()
	local object = {} :: PreviewUI
	local playerGui = player:WaitForChild("PlayerGui")

	object.baseUI = baseUI
	object.session = session
	object.previewTool = previewTool
	object.style = baseUI.style
	object.hasSeenAccessoryAdjustmentModal = false
	object.maid = maid

	object.screenGui = maid:add(Create("ScreenGui", {
		Name = "PreviewUI",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		ResetOnSpawn = false,
		ScreenInsets = if GuiService:IsTenFootInterface()
			then Enum.ScreenInsets.None
			else Enum.ScreenInsets.CoreUISafeInsets,
		Parent = playerGui,
	})) :: ScreenGui

	object.style:linkGui(object.screenGui)

	object.frame = Create("Frame", {
		Tags = { StyleConsts.tags.PreviewUIParent },
		Parent = object.screenGui,
	}) :: Frame

	local function previewCurrentSelection()
		if object.currentSelection == 1 then
			object.previewTool:moveCameraToRoxy()
		else
			object.previewTool:moveCameraToPlayerAvatar()
		end
	end

	local function previewOnDefault()
		object.currentSelection = 1
		previewCurrentSelection()
	end

	local function getShouldSeeAdjustmentModal()
		local avatarAssetType = object.session.modelInfo:getAvatarAssetType()

		if avatarAssetType then
			return CreationConfig.adjustableRigidAccessories[avatarAssetType]
		else
			return false
		end
	end

	local function previewOnAvatar()
		if not object.hasSeenAccessoryAdjustmentModal and getShouldSeeAdjustmentModal() then
			object.hasSeenAccessoryAdjustmentModal = true
			object.baseUI.accessoryAdjustmentModalUI:open()
		end
		object.currentSelection = 2
		previewCurrentSelection()
	end

	object.switcher = maid:add(SegmentedControl({
		{
			text = "Default",
			callback = previewOnDefault,
		},
		{
			text = "My Avatar",
			callback = previewOnAvatar,
		},
	}))
	object.switcher.frame.Parent = object.frame
	StyleUtils.addStyleTag(object.switcher.frame, StyleConsts.tags.AvatarPreviewSwitcher)

	object.currentSelection = 1

	object.screenGui.Enabled = false

	--[=[
		@within PreviewUI

		Puts the creation onto the preview bodies and frames whichever one is selected.
	]=]
	function object:show()
		self.screenGui.Enabled = true

		self.previewTool:applyAccessoryToBodies()
		previewCurrentSelection()
	end

	--[=[
		@within PreviewUI
	]=]
	function object:hide()
		self.screenGui.Enabled = false

		self.previewTool:endPreview()
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return PreviewUI

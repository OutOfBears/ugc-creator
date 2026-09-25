local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Modal = require("../Components/Modal")
local Overlay = require("../Components/Overlay")

local player = Players.LocalPlayer

export type AccessoryAdjustmentModalUI = {
	-- vars
	baseUI: any,
	session: any,
	screenGui: ScreenGui,
	maid: Maid.Maid,
	-- methods
	open: (self: AccessoryAdjustmentModalUI) -> (),
	close: (self: AccessoryAdjustmentModalUI) -> (),
	destroy: (self: AccessoryAdjustmentModalUI) -> (),
}

--[=[
	@class AccessoryAdjustmentModalUI
	@client

	One-time warning that an accessory may not sit perfectly on a real avatar, surfaced the first
	time [PreviewUI] previews on the player's own body. Owned by [BaseUI].
]=]
local function AccessoryAdjustmentModalUI(baseUI: any, session: any): AccessoryAdjustmentModalUI
	local maid = Maid.new()
	local object = {} :: AccessoryAdjustmentModalUI
	local playerGui = player:WaitForChild("PlayerGui")

	object.baseUI = baseUI
	object.session = session
	object.maid = maid

	object.screenGui = maid:add(Create("ScreenGui", {
		Name = "AccessoryAdjustmentModalUI",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		Enabled = false,
		Parent = playerGui,
	})) :: ScreenGui

	baseUI.style:linkGui(object.screenGui)

	local overlay = Overlay()
	overlay.Parent = object.screenGui

	local buttonInfos = {
		{
			text = "Ok",
			callback = function()
				object:close()
			end,
		},
	}

	local modal = Modal(CreationStrings.accessoryAdjustmentTitle, CreationStrings.accessoryAdjustmentBody, buttonInfos)
	modal.Parent = object.screenGui

	--[=[
		@within AccessoryAdjustmentModalUI
	]=]
	function object:open()
		self.screenGui.Enabled = true
	end

	--[=[
		@within AccessoryAdjustmentModalUI
	]=]
	function object:close()
		self.screenGui.Enabled = false
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return AccessoryAdjustmentModalUI

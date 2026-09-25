local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Modal = require("../Components/Modal")
local Overlay = require("../Components/Overlay")

local player = Players.LocalPlayer

export type ResetEditsModalUI = {
	-- vars
	baseUI: any,
	session: any,
	screenGui: ScreenGui,
	maid: Maid.Maid,
	-- methods
	open: (self: ResetEditsModalUI) -> (),
	close: (self: ResetEditsModalUI) -> (),
	destroy: (self: ResetEditsModalUI) -> (),
}

--[=[
	@class ResetEditsModalUI
	@client

	Confirmation for the top bar's reset button. It gets its own ScreenGui so it sits above every
	other handler's. Owned by [BaseUI].
]=]
local function ResetEditsModalUI(baseUI: any, session: any): ResetEditsModalUI
	local maid = Maid.new()
	local object = {} :: ResetEditsModalUI
	local playerGui = player:WaitForChild("PlayerGui")

	object.baseUI = baseUI
	object.session = session
	object.maid = maid

	object.screenGui = maid:add(Create("ScreenGui", {
		Name = "ModalUI",
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
				object.session:resetModelInfo()
			end,
		},
		{
			text = "Cancel",
			callback = function()
				object:close()
			end,
		},
	}

	local modal = Modal(CreationStrings.resetEditsTitle, CreationStrings.resetEditsBody, buttonInfos)
	modal.Parent = object.screenGui

	--[=[
		@within ResetEditsModalUI
	]=]
	function object:open()
		self.screenGui.Enabled = true
	end

	--[=[
		@within ResetEditsModalUI
	]=]
	function object:close()
		self.screenGui.Enabled = false
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return ResetEditsModalUI

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local LocalMenu = require("../Components/LocalMenu")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")

local player = Players.LocalPlayer

export type TopBarUI = {
	-- vars
	baseUI: any,
	session: any,
	screenGui: ScreenGui,
	editorMenu: GuiObject,
	previewMenu: GuiObject?,
	maid: Maid.Maid,
	-- methods
	hideBehindPanel: (self: TopBarUI) -> (),
	unhideBehindPanel: (self: TopBarUI) -> (),
	destroy: (self: TopBarUI) -> (),
}

--[=[
	@class TopBarUI
	@client

	The editor's top bar: reset, exit, and — on accessories — the buttons that swap between the
	editor and the avatar preview. Owned by [BaseUI].
]=]
local function TopBarUI(baseUI: any, session: any): TopBarUI
	local maid = Maid.new()
	local object = {} :: TopBarUI
	local playerGui = player:WaitForChild("PlayerGui")

	object.baseUI = baseUI
	object.session = session
	object.maid = maid

	local showAvatarPreview = session.modelInfo:getCreationType() == CreationConfig.creationTypes.accessory

	object.screenGui = maid:add(Create("ScreenGui", {
		Name = "TopBarUI",
		ScreenInsets = if GuiService:IsTenFootInterface()
			then Enum.ScreenInsets.None
			else Enum.ScreenInsets.TopbarSafeInsets,
		Parent = playerGui,
	})) :: ScreenGui

	baseUI.style:linkGui(object.screenGui)

	local function switchToEditor()
		object.editorMenu.Visible = true
		if object.previewMenu then
			object.previewMenu.Visible = false
		end
		object.baseUI:returnToEditor()
	end

	local function switchToAvatarPreview()
		object.editorMenu.Visible = false
		if object.previewMenu then
			object.previewMenu.Visible = true
		end
		object.baseUI:openAvatarPreview()
	end

	local editorInfos = {}
	local previewInfos = nil

	local onDestroy = function()
		baseUI.resetEditsModalUI:open()
	end
	local destroyButtonInfo = {
		iconId = CreationIcons.icons.ResetChanges,
		callback = onDestroy,
	}
	table.insert(editorInfos, { destroyButtonInfo })

	local onExit = function()
		session:quit()
	end
	local exitButtonInfo = {
		iconId = CreationIcons.icons.ExitEditor,
		callback = onExit,
	}
	table.insert(editorInfos, { exitButtonInfo })

	if showAvatarPreview then
		local previewButtonInfo = {
			iconId = CreationIcons.icons.AvatarPreview,
			callback = switchToAvatarPreview,
		}
		table.insert(editorInfos, 2, { previewButtonInfo })

		local modelName = session.modelInfo:getBlankName()

		local returnButtonInfo = {
			iconId = CreationIcons.editorIcons[modelName],
			callback = switchToEditor,
		}
		previewInfos = { { returnButtonInfo }, { exitButtonInfo } }
	end

	object.editorMenu = LocalMenu(editorInfos)
	object.editorMenu.Parent = object.screenGui
	object.editorMenu.Name = "EditorLocalMenu"

	if showAvatarPreview then
		object.previewMenu = LocalMenu(previewInfos)
		local previewMenu = object.previewMenu :: GuiObject
		previewMenu.Visible = false
		previewMenu.Parent = object.screenGui
		previewMenu.Name = "PreviewLocalMenu"
	end

	--[=[
		@within TopBarUI

		Panels only open in editing mode, so only the editor menu ever needs to move aside.
	]=]
	function object:hideBehindPanel()
		StyleUtils.addStyleTag(self.editorMenu, StyleConsts.tags.CoreUIWithOpenPanel)
	end

	--[=[
		@within TopBarUI
	]=]
	function object:unhideBehindPanel()
		StyleUtils.removeStyleTag(self.editorMenu, StyleConsts.tags.CoreUIWithOpenPanel)
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return TopBarUI

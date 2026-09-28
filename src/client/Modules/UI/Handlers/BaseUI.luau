local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessoryAdjustmentModalUI = require("./AccessoryAdjustmentModalUI")
local CoreGuiController = require("../../../Controllers/CoreGuiController")
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local EditingUI = require("./EditingUI")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local Network = require(ReplicatedStorage.Shared.Modules.Network).client()
local PreviewUI = require("./PreviewUI")
local ResetEditsModalUI = require("./ResetEditsModalUI")
local StyleConsts = require("../Style/StyleConsts")
local StyleSheet = require("../Style/StyleSheet")
local StyleUtils = require("../Style/StyleUtils")
local TextButton = require("../Components/TextButton")
local TopBarUI = require("./TopBarUI")

local player = Players.LocalPlayer

export type BaseUI = {
	-- vars
	session: any,
	screenGui: ScreenGui,
	style: StyleSheet.Style,
	creationPrice: number,
	buyButton: TextButton,
	topBarUI: TopBarUI.TopBarUI,
	resetEditsModalUI: ResetEditsModalUI.ResetEditsModalUI,
	accessoryAdjustmentModalUI: AccessoryAdjustmentModalUI.AccessoryAdjustmentModalUI,
	editingUI: EditingUI.EditingUI,
	previewUI: PreviewUI.PreviewUI,
	maid: Maid.Maid,
	-- methods
	hideCoreUIBehindPanel: (self: BaseUI) -> (),
	unhideCoreUIBehindPanel: (self: BaseUI) -> (),
	openAvatarPreview: (self: BaseUI) -> (),
	returnToEditor: (self: BaseUI) -> (),
	destroy: (self: BaseUI) -> (),
}

--[=[
	@class BaseUI
	@client

	The editor's top-level UI handler, and the entry point to the handler layer.

	Each handler under `Handlers/` builds one or more ScreenGuis and wires [Components] to the
	session and tool logic behind them. Handlers are the experience-specific half of the UI —
	they depend on the [CreationSession], tool and [ModelInfo] interfaces, where `Components/`
	and `Style/` depend only on each other and port anywhere. [ExampleUI] is the one portable
	handler, kept as a template rather than as live UI.

	BaseUI owns the shared [StyleSheet] every other handler links its gui into, and constructs
	and destroys the rest of them: [TopBarUI], [EditingUI], [PreviewUI] and the two modals. It
	also holds the editor-scoped display state — landscape orientation, core gui and chat off,
	jumping disabled — all of which it restores on `destroy`.
]=]
local function BaseUI(
	session: any,
	modelInfo: any,
	fabricTool: any,
	stickerTool: any,
	brushTool: any,
	kitbashTool: any,
	previewTool: any,
	layerColorTool: any,
	layersTool: any
): BaseUI
	local maid = Maid.new()
	local object = {} :: BaseUI
	local playerGui = player:WaitForChild("PlayerGui")

	object.session = session
	object.maid = maid

	local previousScreenOrientation = playerGui.ScreenOrientation
	playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight

	CoreGuiController.disableCoreGui(Enum.CoreGuiType.All)
	CoreGuiController.setCore("ChatActive", false)

	local character = player.Character
	if not character or character.Parent == nil then
		character = player.CharacterAdded:Wait()
	end

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	object.screenGui = maid:add(Create("ScreenGui", {
		Name = "BaseUI",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		Tags = { StyleConsts.tags.BaseUI },
		Parent = playerGui,
	})) :: ScreenGui

	object.style = maid:add(StyleSheet())
	object.style:linkGui(object.screenGui)

	object.creationPrice = modelInfo:getCreationPrice()

	stickerTool:connectHandlesToStyle(object.style)
	kitbashTool:connectHandlesToStyle(object.style)

	object.topBarUI = maid:add(TopBarUI(object, session))
	object.resetEditsModalUI = maid:add(ResetEditsModalUI(object, session))
	object.accessoryAdjustmentModalUI = maid:add(AccessoryAdjustmentModalUI(object, session))
	object.editingUI = maid:add(
		EditingUI(object, session, fabricTool, stickerTool, brushTool, kitbashTool, layerColorTool, layersTool)
	)
	object.previewUI = maid:add(PreviewUI(object, session, previewTool))

	local buyButtonText = if object.creationPrice > 0
		then `{CreationStrings.robuxIcon} {object.creationPrice}`
		else CreationStrings.publishButton

	object.buyButton = TextButton({
		text = buyButtonText,
		callback = function()
			Network.fire("PublishModel")
			session:quit()
		end,
	})
	object.buyButton.Name = "BuyButton"
	object.buyButton.Parent = object.screenGui

	StyleUtils.addStyleTag(object.buyButton, StyleConsts.tags.BuyButton)
	StyleUtils.addStyleTag(object.buyButton, StyleConsts.tags.EmphasisButton)

	--[=[
		@within BaseUI

		Tucks the buy button and top bar away so an open panel has the screen to itself.
	]=]
	function object:hideCoreUIBehindPanel()
		StyleUtils.addStyleTag(self.buyButton, StyleConsts.tags.CoreUIWithOpenPanel)
		self.topBarUI:hideBehindPanel()
	end

	--[=[
		@within BaseUI
	]=]
	function object:unhideCoreUIBehindPanel()
		StyleUtils.removeStyleTag(self.buyButton, StyleConsts.tags.CoreUIWithOpenPanel)
		self.topBarUI:unhideBehindPanel()
	end

	--[=[
		@within BaseUI

		Swaps the editing tools out for the avatar preview.
	]=]
	function object:openAvatarPreview()
		self.previewUI:show()
		self.editingUI:hide()
	end

	--[=[
		@within BaseUI
	]=]
	function object:returnToEditor()
		self.previewUI:hide()
		self.editingUI:show()
	end

	function object:destroy()
		maid:doCleaning()

		CoreGuiController.enableCoreGui(Enum.CoreGuiType.All)
		CoreGuiController.setCore("ChatActive", true)

		playerGui.ScreenOrientation = previousScreenOrientation

		local currentCharacter = player.Character
		local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")

		if currentHumanoid then
			(currentHumanoid :: Humanoid):SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
	end

	return object
end

return BaseUI

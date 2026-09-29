local GamepadService = game:GetService("GamepadService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AccessorySwapTool = require("./Tools/AccessorySwapTool")
local Actions = require(ReplicatedStorage.Shared.Modules.Actions)
local BrushTool = require("./Tools/BrushTool")
local CameraManager = require("./CameraManager")
local Charm = require(ReplicatedStorage.Packages.Charm)
local ClientAtoms = require("./ClientAtoms")
local CoreGuiController = require("../Controllers/CoreGuiController")
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationInput = require("./CreationInput")
local CreationPanels = require("./CreationPanels")
local FabricTool = require("./Tools/FabricTool")
local KitbashTool = require("./Tools/KitbashTool")
local LayerColorTool = require("./Tools/LayerColorTool")
local LayersTool = require("./Tools/LayersTool")
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local MeshEditingWidgets = require("./MeshEditingWidgets")
local ModelDisplay = require("./ModelDisplay")
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)
local Network = require(ReplicatedStorage.Shared.Modules.Network).client()
local PreviewTool = require("./Tools/PreviewTool")
local StickerTool = require("./Tools/StickerTool")

local player = Players.LocalPlayer

local nextSessionId = 0

export type Screen = "edit" | "preview"
export type Modal = "resetEdits" | "accessoryAdjustment"

export type CreationSession = {
	-- vars
	id: number,
	modelInfo: ModelInfo.ModelInfo,
	cameraManager: CameraManager.CameraManager,
	modelDisplay: ModelDisplay.ModelDisplay,
	creationInput: CreationInput.CreationInput,
	meshEditingWidgets: MeshEditingWidgets.MeshEditingWidgets,
	brushTool: BrushTool.BrushTool,
	fabricTool: FabricTool.FabricTool,
	stickerTool: StickerTool.StickerTool,
	kitbashTool: KitbashTool.KitbashTool,
	previewTool: PreviewTool.PreviewTool?,
	layerColorTool: LayerColorTool.LayerColorTool?,
	accessorySwapTool: AccessorySwapTool.AccessorySwapTool?,
	layersTool: LayersTool.LayersTool,
	panels: CreationPanels.CreationPanels,
	screen: Charm.Atom<Screen>,
	modal: Charm.Atom<Modal?>,
	previewTarget: Charm.Atom<number>,
	hasSeenAccessoryAdjustment: boolean,
	editMode: number,
	cameraResetPosition: Vector3,
	maid: Maid.Maid,
	onQuit: (() -> ())?,
	onRequestReset: (() -> ())?,
	-- methods
	resetModelInfo: (self: CreationSession) -> (),
	setEditMode: (self: CreationSession, editMode: number) -> (),
	getEditMode: (self: CreationSession) -> number,
	exitEditMode: (self: CreationSession) -> (),
	resetCamera: (self: CreationSession) -> (),
	panToLeft: (self: CreationSession) -> (),
	getWidgetGroupNames: (self: CreationSession) -> { string },
	showMeshEditControls: (self: CreationSession, controlGroupName: string) -> (),
	hideMeshEditControls: (self: CreationSession) -> (),
	isShowingMeshEditControls: (self: CreationSession) -> boolean,
	getCreationInput: (self: CreationSession) -> CreationInput.CreationInput,
	getCreationType: (self: CreationSession) -> string,
	openAvatarPreview: (self: CreationSession) -> (),
	returnToEditor: (self: CreationSession) -> (),
	setPreviewTarget: (self: CreationSession, target: number) -> (),
	publish: (self: CreationSession) -> (),
	quit: (self: CreationSession) -> (),
	destroy: (self: CreationSession) -> (),
}

-- Mounted from `assets/PlayerModule.rbxm` into StarterPlayerScripts, so it replicates into
-- PlayerScripts rather than being injected by the engine — wait for it instead of indexing it,
-- since a player can click a kiosk before their PlayerScripts have finished populating.
local function playerControls(): any
	local playerScripts = player:WaitForChild("PlayerScripts")
	local playerModule = require(playerScripts:WaitForChild("PlayerModule")) :: any

	return playerModule:GetControls()
end

--[=[
	@class CreationSession
	@client

	One editing session over one [ModelInfo] — the camera, input, display, the five tools and
	the UI, built together and torn down together.

	[CreationController] owns the lifecycle; the React views reach it through
	`ClientAtoms.creationSession` and call back into it. A session is created and destroyed every
	time the player opens or leaves the editor, so it is deliberately not a singleton. `screen`,
	`modal` and `previewTarget` are the editor-wide UI state those views render from.
]=]
local function CreationSession(modelInfo: ModelInfo.ModelInfo): CreationSession
	local maid = Maid.new()
	local object = {} :: CreationSession

	playerControls():Disable()

	nextSessionId += 1
	object.id = nextSessionId
	object.modelInfo = modelInfo
	object.editMode = CreationConfig.editModes.none
	object.cameraResetPosition = workspace.CurrentCamera.CFrame.Position
	object.screen = Charm.atom("edit" :: Screen)
	object.modal = Charm.atom(nil :: Modal?)
	object.previewTarget = Charm.atom(1)
	object.hasSeenAccessoryAdjustment = false
	object.maid = maid

	--[=[
		@within CreationSession
		@param editMode number -- one of [CreationConfig].`editModes`
	]=]
	function object:setEditMode(editMode: number)
		self.editMode = editMode
	end

	--[=[
		@within CreationSession
		@return number -- the active mode, one of [CreationConfig].`editModes`
	]=]
	function object:getEditMode(): number
		return self.editMode
	end

	--[=[
		@within CreationSession

		Leaves the current tool and returns the model to its resting pose.
	]=]
	function object:exitEditMode()
		self:setEditMode(CreationConfig.editModes.none)
		self.modelDisplay:onExitedEditMode()
	end

	--[=[
		@within CreationSession
	]=]
	function object:resetCamera()
		self.cameraManager:resetCamera(true)
	end

	--[=[
		@within CreationSession

		Slides the model left so an open panel does not cover it.
	]=]
	function object:panToLeft()
		self.cameraManager:panToLeft(ClientAtoms.isMobile())
	end

	--[=[
		@within CreationSession
		@return { string } -- the blank's mesh-edit control group names, sorted alphabetically
	]=]
	function object:getWidgetGroupNames(): { string }
		local names = {}

		for name in self.modelInfo.meshInfo.widgetInfo do
			table.insert(names, name)
		end

		table.sort(names)

		return names
	end

	--[=[
		@within CreationSession
		@param controlGroupName string -- a name from [CreationSession:getWidgetGroupNames]
	]=]
	function object:showMeshEditControls(controlGroupName: string)
		self.modelDisplay:resetModel()
		self.meshEditingWidgets:setupWidgets(controlGroupName)
	end

	--[=[
		@within CreationSession

		Hides the deform widgets and commits the deformation to both the local model and the
		server's authoritative copy.
	]=]
	function object:hideMeshEditControls()
		self.meshEditingWidgets:hideWidgets()

		local action = Actions.createAction(Actions.ActionTypes.UpdateDeformedEditableMeshes, {})

		Actions.executeAction(self.modelInfo, action)
		Network.fire("SubmitAction", action)
	end

	--[=[
		@within CreationSession
		@return boolean -- true while the deform widgets are on screen
	]=]
	function object:isShowingMeshEditControls(): boolean
		return self.meshEditingWidgets:isShowingWidgets()
	end

	--[=[
		@within CreationSession
		@return CreationInput -- the session's gesture handler
	]=]
	function object:getCreationInput(): CreationInput.CreationInput
		return self.creationInput
	end

	--[=[
		@within CreationSession
		@return string -- `"Body"` or `"Accessory"`
	]=]
	function object:getCreationType(): string
		return self.modelInfo:getCreationType()
	end

	local function previewCurrentTarget()
		local previewTool = object.previewTool :: PreviewTool.PreviewTool
		if object.previewTarget() == 1 then
			previewTool:moveCameraToRoxy()
		else
			previewTool:moveCameraToPlayerAvatar()
		end
	end

	--[=[
		@within CreationSession

		Swaps the editing tools out for the avatar preview. Accessories only.
	]=]
	function object:openAvatarPreview()
		self.panels:hide()
		self.screen("preview")

		local previewTool = self.previewTool :: PreviewTool.PreviewTool
		previewTool:applyAccessoryToBodies()
		previewCurrentTarget()
	end

	--[=[
		@within CreationSession
	]=]
	function object:returnToEditor()
		local previewTool = self.previewTool :: PreviewTool.PreviewTool
		previewTool:endPreview()

		self.screen("edit")
		self.panels:show()
	end

	--[=[
		@within CreationSession
		@param target number -- 1 previews on the stock avatar, 2 on the player's own

		The first switch to the player's own avatar warns that rigid accessories may need adjusting.
	]=]
	function object:setPreviewTarget(target: number)
		local avatarAssetType = self.modelInfo:getAvatarAssetType()
		local shouldWarn = avatarAssetType ~= nil and CreationConfig.adjustableRigidAccessories[avatarAssetType]

		if target == 2 and not self.hasSeenAccessoryAdjustment and shouldWarn then
			self.hasSeenAccessoryAdjustment = true
			self.modal("accessoryAdjustment")
		end

		self.previewTarget(target)
		previewCurrentTarget()
	end

	--[=[
		@within CreationSession

		Publishes the creation and leaves the editor.
	]=]
	function object:publish()
		Network.fire("PublishModel")
		self:quit()
	end

	--[=[
		@within CreationSession

		Tears the session down and hands the camera and controls back to the player. The
		[ModelInfo] outlives this call — [CreationController] reuses it when the player
		re-opens the same blank.
	]=]
	function object:quit()
		local onQuit = self.onQuit
		self.onQuit = nil

		self:destroy()

		if onQuit then
			onQuit()
		end
	end

	--[=[
		@within CreationSession

		Discards every edit and reopens the same blank from scratch. The rebuild belongs to
		[CreationController], which owns the model's lifetime, so this only signals it —
		injecting the callback is what keeps the two modules from requiring each other.
	]=]
	function object:resetModelInfo()
		local onRequestReset = self.onRequestReset

		if onRequestReset then
			onRequestReset()
		end
	end

	function object:destroy()
		if ClientAtoms.creationSession() == object then
			ClientAtoms.creationSession(nil)
		end

		maid:doCleaning()

		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local characterRoot = character and character:FindFirstChild("HumanoidRootPart")

		if humanoid and characterRoot then
			camera.CameraSubject = humanoid
			camera.FieldOfView = CreationConfig.camera.playerFieldOfView
			camera.CFrame = CFrame.lookAt(object.cameraResetPosition, (characterRoot :: BasePart).CFrame.Position)
		end

		playerControls():Enable()

		if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
			GamepadService:DisableGamepadCursor(nil)
		end
	end

	-- Built last: CreationPanels and the canvas call back into this object during their own
	-- construction, so every method above must already exist by the time they run.

	object.cameraManager = maid:add(CameraManager(modelInfo))
	object.modelDisplay = maid:add(ModelDisplay(modelInfo))
	object.creationInput = maid:add(CreationInput(object.cameraManager, object.modelDisplay))

	object.brushTool = maid:add(BrushTool(modelInfo, object.creationInput))
	object.fabricTool = maid:add(FabricTool(modelInfo))
	object.stickerTool = maid:add(StickerTool(modelInfo, object.creationInput))
	object.kitbashTool = maid:add(KitbashTool(modelInfo, object.creationInput, object.modelDisplay))
	object.layersTool = maid:add(LayersTool(modelInfo, object.brushTool, object.stickerTool))

	if modelInfo:getCreationType() == CreationConfig.creationTypes.accessory then
		object.previewTool = maid:add(PreviewTool(modelInfo, object.cameraManager, object.modelDisplay))
	end

	if modelInfo:getLayerCatalog() then
		object.layerColorTool = maid:add(LayerColorTool(modelInfo))
	end

	if modelInfo:getAccessoryCatalog() then
		object.accessorySwapTool = maid:add(AccessorySwapTool(modelInfo))
	end

	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local previousScreenOrientation = playerGui.ScreenOrientation
	playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight
	CoreGuiController.disableCoreGui(Enum.CoreGuiType.All)
	CoreGuiController.setCore("ChatActive", false)

	local character = player.Character
	if not character or character.Parent == nil then
		character = player.CharacterAdded:Wait()
	end
	local humanoid = (character :: Model):WaitForChild("Humanoid") :: Humanoid
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	maid:add(function()
		CoreGuiController.enableCoreGui(Enum.CoreGuiType.All)
		CoreGuiController.setCore("ChatActive", true)
		playerGui.ScreenOrientation = previousScreenOrientation

		local currentCharacter = player.Character
		local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
		if currentHumanoid then
			currentHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
	end)

	object.panels = maid:add(CreationPanels(object))

	object.meshEditingWidgets =
		maid:add(MeshEditingWidgets(modelInfo, object.modelDisplay, object.creationInput, object.cameraManager))

	if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
		GamepadService:EnableGamepadCursor(nil)
	end

	maid:add(UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
			GamepadService:EnableGamepadCursor(nil)
		else
			GamepadService:DisableGamepadCursor(nil)
		end
	end))

	ClientAtoms.creationSession(object)

	return object
end

return CreationSession

local GamepadService = game:GetService("GamepadService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Actions = require(ReplicatedStorage.Shared.Modules.Actions)
local BaseUI = require("./UI/Handlers/BaseUI")
local BrushTool = require("./Tools/BrushTool")
local CameraManager = require("./CameraManager")
local ClientAtoms = require("./ClientAtoms")
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationInput = require("./CreationInput")
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
local StyleUtils = require("./UI/Style/StyleUtils")

local player = Players.LocalPlayer

local nextSessionId = 0

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
	layersTool: LayersTool.LayersTool,
	baseUI: BaseUI.BaseUI,
	editMode: number,
	isMobile: boolean,
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
	panForCanvas: (self: CreationSession) -> (),
	getWidgetGroupNames: (self: CreationSession) -> { string },
	showMeshEditControls: (self: CreationSession, controlGroupName: string) -> (),
	hideMeshEditControls: (self: CreationSession) -> (),
	isShowingMeshEditControls: (self: CreationSession) -> boolean,
	getCreationInput: (self: CreationSession) -> CreationInput.CreationInput,
	getCreationType: (self: CreationSession) -> string,
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

	[CreationController] owns the lifecycle; this is what the UI handlers are handed and call
	back into. A session is created and destroyed every time the player opens or leaves the
	editor, so it is deliberately not a singleton.
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
		self.cameraManager:panToLeft(self.isMobile)
	end

	--[=[
		@within CreationSession

		Slides the model to the far left so the 2D canvas and its panel both fit beside it.
	]=]
	function object:panForCanvas()
		local viewportWidth = workspace.CurrentCamera.ViewportSize.X
		self.cameraManager:panX(viewportWidth / 2 - viewportWidth * CreationConfig.uvCanvas.modelScreenXScale)
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

	-- Built last: BaseUI and its handlers call back into this object during their own
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

	object.baseUI = maid:add(
		BaseUI(
			object,
			modelInfo,
			object.fabricTool,
			object.stickerTool,
			object.brushTool,
			object.kitbashTool,
			object.previewTool,
			object.layerColorTool,
			object.layersTool
		)
	)

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

	local screenGui = object.baseUI.screenGui
	object.isMobile = StyleUtils.getIsMobile(screenGui)

	maid:add(screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		object.isMobile = StyleUtils.getIsMobile(screenGui)
	end))

	ClientAtoms.creationSession(object)

	return object
end

return CreationSession

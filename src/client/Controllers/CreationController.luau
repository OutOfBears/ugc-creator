local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessoryUtils = require(ReplicatedStorage.Shared.Modules.Utils.AccessoryUtils)
local AttachmentUtils = require(ReplicatedStorage.Shared.Modules.Utils.AttachmentUtils)
local Blanks = require(ReplicatedStorage.Shared.Data.Blanks)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationSession = require("../Modules/CreationSession")
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local LoadingScreen = require("../Modules/UI/LoadingScreen")
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local Message = require("../Modules/UI/Message")
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)
local Network = require(ReplicatedStorage.Shared.Modules.Network).client()
local ResolutionManager = require(ReplicatedStorage.Shared.Modules.ResolutionManager)
local StyleSheet = require("../Modules/UI/Style/StyleSheet")
local SwitchEditorsModalUI = require("../Modules/UI/Handlers/SwitchEditorsModalUI")
local Types = require(ReplicatedStorage.Shared.Types)

local logger = Logger.new()

local activeSession: CreationSession.CreationSession? = nil
local lastModelInfo: ModelInfo.ModelInfo? = nil
local resolutionIndex = 1
local debounced = false

--[=[
	@class CreationController
	@client

	Opens and closes the item creation editor.

	Owns what has to outlive a single editing session: the [ModelInfo] the player is building
	(so their edits survive leaving and re-entering the same blank) and the texture resolution
	the client is currently able to afford. Each visit builds a fresh [CreationSession] over
	that model.

	Editable images are the scarce resource here. Building a blank can fail outright on
	memory-constrained devices, so [CreationController.open] retries down the
	[CreationConfig].`textureResolutionSteps` ladder, resetting the server's copy between
	attempts to free what the failed attempt allocated.
]=]
local CreationController = {} :: Types.Controller & {
	open: (blankName: string) -> (),
}

local function destroyLastModel()
	if not lastModelInfo then
		return
	end

	Network.invokeServer("ResetModel")

	lastModelInfo:destroy()
	lastModelInfo = nil
end

local function averageMeshPartPosition(model: Model): Vector3
	local total = Vector3.zero
	local count = 0

	for _, child in model:GetDescendants() do
		if child:IsA("MeshPart") then
			total += child.Position
			count += 1
		end
	end

	return if count > 0 then total / count else Vector3.zero
end

local function frameCameraOnModel(modelInfo: ModelInfo.ModelInfo)
	modelInfo:initializeMeshPartPositions()

	local target = averageMeshPartPosition(modelInfo:getModel())
	local camera = workspace.CurrentCamera

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CreationConfig.camera.editFieldOfView
	camera.CFrame = CFrame.lookAt(target + Vector3.new(0, 0, 10), target)
end

local function buildClientModel(blank: Blanks.Blank): Model
	LoadingScreen.setVisible(true)

	local model = blank.sourceModel:Clone()

	-- Setup yields for a while after this model enters Workspace, and ModelInfo only resets part
	-- positions afterwards, so an unanchored part would keep whatever rotation it fell into.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end

	model.Parent = workspace

	if blank.creationType == CreationConfig.creationTypes.body and not blank.layerCatalogName then
		AttachmentUtils.buildRigFromAttachments(model)
		AccessoryUtils.reapplyLayeredClothing(model)
	end

	return model
end

local function initModelFromBlank(blank: Blanks.Blank): ModelInfo.ModelInfo
	destroyLastModel()

	local model = buildClientModel(blank)

	Network.fire("InitializeModel", blank.name, resolutionIndex)

	local creationPrice = Network.invokeServer("GetCreationPrice", blank.avatarAssetType)

	return ModelInfo(model, blank, { creationPrice = creationPrice, resolutionIndex = resolutionIndex })
end

local function startSession(modelInfo: ModelInfo.ModelInfo)
	logger:debug(`Starting session for '{modelInfo:getBlankName()}'`)

	-- Switching editors can reach here with one already open. Without this the new session
	-- stacks on the old: both ScreenGuis stay up, two CameraManagers fight over CurrentCamera,
	-- and the controls get disabled twice — which reads as the new editor never appearing.
	local previous = activeSession
	if previous then
		logger:debug("Tearing down the previous session first")
		activeSession = nil
		previous.onQuit = nil
		previous:destroy()
	end

	frameCameraOnModel(modelInfo)

	local session = CreationSession(modelInfo)
	activeSession = session

	session.onQuit = function()
		if activeSession == session then
			activeSession = nil
		end
	end

	session.onRequestReset = function()
		LoadingScreen.setVisible(true)

		local blankName = modelInfo:getBlankName()

		session:quit()
		destroyLastModel()

		CreationController.open(blankName)
	end
end

-- Building a blank allocates every editable image up front, so an out-of-memory failure is
-- expected on low-end devices rather than exceptional. Each retry drops a resolution rung and
-- resets the server's copy so the failed attempt's allocations are actually released.
local function runAttempts(attempt: () -> ())
	resolutionIndex = 1

	local maxAttempts = ResolutionManager.stepCount()

	for attemptNumber = 1, maxAttempts do
		local ok, err = pcall(attempt)

		if ok then
			return
		end

		logger:warn(tostring(err))

		if string.find(tostring(err), CreationStrings.failedToCreateImage, 1, true) then
			if attemptNumber == maxAttempts then
				task.spawn(Message.create, "Setup failed, out of memory.")
				return
			end

			logger:warn(`Stepping resolution down and retrying (attempt {attemptNumber} of {maxAttempts})`)
			resolutionIndex = ResolutionManager.clampIndex(resolutionIndex + 1)

			Network.invokeServer("ResetModel")
		elseif string.find(tostring(err), CreationStrings.fixMeshImageSettings, 1, true) then
			task.spawn(
				Message.create,
				"EditableImage and EditableMesh are not accessible. Go to the Security Tab in Game Settings to enable this API."
			)
			return
		else
			task.spawn(Message.create, "Unexpected error.")
			return
		end
	end
end

--[=[
	@within CreationController
	@yields
	@param attempt () -> () -- builds a model and starts a session

	Runs `attempt`, stepping the texture resolution down and retrying on an out-of-memory
	failure, and lowers the loading cover however it ends.

	The cover is raised in `buildClientModel` on every path that builds a model, so lowering it
	here — rather than at one call site — is what stops a branch from leaving the screen
	covered over a perfectly good editor.
]=]
local function withResolutionRetry(attempt: () -> ())
	runAttempts(attempt)
	LoadingScreen.setVisible(false)
end

local function openSwitchEditorsModal(blank: Blanks.Blank)
	local style = StyleSheet()

	local function onBuy()
		Network.fire("PublishModel")
		style:destroy()
	end

	local function onContinue()
		logger:debug(`Switching editors into '{blank.name}'`)

		withResolutionRetry(function()
			lastModelInfo = initModelFromBlank(blank)
			startSession(lastModelInfo :: ModelInfo.ModelInfo)
			style:destroy()
		end)
	end

	local function onCancel()
		style:destroy()
	end

	local creationPrice = if lastModelInfo then lastModelInfo:getCreationPrice() else 0

	SwitchEditorsModalUI(style, creationPrice, onBuy, onContinue, onCancel)
end

--[=[
	@within CreationController
	@yields
	@param blankName string -- a blank name, e.g. `"RobotModel"`

	Opens the editor on a blank.

	Re-opening the blank the player was last editing resumes it with their edits intact.
	Opening a *different* blank prompts first, since switching discards the current creation.
	Calls are debounced for a few seconds so a kiosk cannot be spam-clicked into overlapping
	setups.
]=]
function CreationController.open(blankName: string)
	if debounced then
		logger:debug(`Ignoring open('{blankName}') — still debounced`)
		-- Bailing out here skips withResolutionRetry, so lower a cover the reset path raised.
		LoadingScreen.setVisible(false)
		return
	end
	debounced = true

	logger:debug(`Opening '{blankName}'`)

	withResolutionRetry(function()
		local blank = Blanks.get(blankName)
		if not blank then
			logger:warn(`No blank found named '{blankName}'`)
			return
		end

		if not lastModelInfo then
			lastModelInfo = initModelFromBlank(blank)
		elseif (lastModelInfo :: ModelInfo.ModelInfo):getBlankName() ~= blankName then
			logger:debug(
				`Already editing '{(lastModelInfo :: ModelInfo.ModelInfo):getBlankName()}' — prompting to switch`
			)
			openSwitchEditorsModal(blank)
			return
		end

		startSession(lastModelInfo :: ModelInfo.ModelInfo)
	end)

	task.delay(CreationConfig.reopenDebounceSeconds, function()
		debounced = false
	end)
end

function CreationController.onRun()
	Network.on("ShowMessage", Message.create)
end

return CreationController

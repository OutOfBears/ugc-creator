local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AccessoryUtils = require(ReplicatedStorage.Shared.Modules.Utils.AccessoryUtils)
local ActionQueue = require("../Modules/ActionQueue")
local Actions = require(ReplicatedStorage.Shared.Modules.Actions)
local AttachmentUtils = require(ReplicatedStorage.Shared.Modules.Utils.AttachmentUtils)
local AvatarPublisher = require("../Modules/AvatarPublisher")
local Blanks = require(ReplicatedStorage.Shared.Data.Blanks)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)
local Network = require(ReplicatedStorage.Shared.Modules.Network).server()
local Types = require(ReplicatedStorage.Shared.Types)

local SERVER_MODEL_FOLDER = "ServerModelStorage"

local logger = Logger.new()
local queues: { [Player]: ActionQueue.ActionQueue } = {}

--[=[
	@class CreationService
	@server

	Owns the authoritative copy of each player's in-progress creation.

	The client edits its own copy for instant feedback and mirrors every edit here as a
	serialized action, so this side is what actually gets published. One [ActionQueue] per
	player; a player can only have one creation open at a time.
]=]
local CreationService = {} :: Types.Service

local function serverModelStorage(): Folder
	local existing = ServerStorage:FindFirstChild(SERVER_MODEL_FOLDER)
	if existing then
		return existing :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = SERVER_MODEL_FOLDER
	folder.Parent = ServerStorage

	return folder
end

local function resetPlayerModel(player: Player)
	local queue = queues[player]
	queues[player] = nil

	if not queue then
		return
	end

	local modelInfo = queue:getModelInfo()
	if modelInfo then
		modelInfo:destroy()
	end

	queue:destroy()
end

local function setupPlayerModel(player: Player, blankName: string, resolutionIndex: number)
	local blank = Blanks.get(blankName)
	if not blank then
		logger:warn(`{player.Name} asked for unknown blank '{blankName}'`)
		return
	end

	if queues[player] then
		logger:warn(`{player.Name} already had a creation open; resetting it`)
		resetPlayerModel(player)
	end

	local queue = ActionQueue(player)
	queues[player] = queue

	local model = blank.sourceModel:Clone()
	model.Parent = if CreationConfig.visualizeServerEdits then workspace else serverModelStorage()

	local modelInfo = ModelInfo(model, blank, { resolutionIndex = resolutionIndex })

	if modelInfo:getCreationType() == CreationConfig.creationTypes.body and not blank.layerCatalogName then
		AttachmentUtils.buildRigFromAttachments(model)
		AccessoryUtils.reapplyLayeredClothing(model)
	end

	queue:setTargetModelInfo(modelInfo)

	if CreationConfig.visualizeServerEdits then
		model:MoveTo(Vector3.new(0, 5, 0))
	end

	-- The player can leave while the blank's assets are still replicating, which strands the
	-- model we just built under a queue nobody owns any more.
	if queues[player] ~= queue then
		modelInfo:destroy()
		queue:destroy()
	end
end

local function receiveAction(player: Player, action: Actions.Action)
	local queue = queues[player]
	if not queue then
		logger:warn(`{player.Name} sent an action with no creation open`)
		return
	end

	if typeof(action) ~= "table" or not Actions.isKnownActionType(action.actionType) then
		logger:warn(`{player.Name} sent an unknown action type`)
		return
	end

	queue:addAction(action)
end

local function publishModel(player: Player)
	local queue = queues[player]
	if not queue then
		logger:warn(`{player.Name} tried to publish with no creation open`)
		return
	end

	queue:flushQueue()

	local modelInfo = queue:getModelInfo()
	if not modelInfo then
		return
	end

	modelInfo:updateOutputColorMap()

	local _success, message = AvatarPublisher.publish(player, modelInfo:getModel():Clone())

	Network.fireClient(player, "ShowMessage", message)
end

function CreationService.onInit()
	Network.setup({
		events = { "InitializeModel", "SubmitAction", "PublishModel", "ShowMessage" },
		functions = { "GetCreationPrice", "ResetModel" },
	})
end

function CreationService.onRun()
	Network.on("InitializeModel", function(player: Player, blankName: string, resolutionIndex: number)
		if typeof(blankName) ~= "string" or typeof(resolutionIndex) ~= "number" then
			return
		end

		setupPlayerModel(player, blankName, resolutionIndex)
	end)

	Network.on("SubmitAction", receiveAction)

	Network.on("PublishModel", publishModel)

	Network.onInvoke("ResetModel", function(player: Player)
		resetPlayerModel(player)

		return true
	end)

	Network.onInvoke("GetCreationPrice", function(_player: Player, avatarAssetType: Enum.AvatarAssetType?)
		return AvatarPublisher.getPrice(avatarAssetType)
	end)

	Players.PlayerRemoving:Connect(resetPlayerModel)
end

return CreationService

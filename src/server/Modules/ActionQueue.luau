local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actions = require(ReplicatedStorage.Shared.Modules.Actions)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)
local Signal = require(ReplicatedStorage.Packages.Signal)

export type ActionQueue = {
	-- vars
	player: Player,
	queue: { Actions.Action },
	actionInProgress: boolean,
	targetModelInfo: ModelInfo.ModelInfo?,
	gotTargetModelInfo: Signal.Signal<()>,
	processingFinished: Signal.Signal<()>,
	maid: Maid.Maid,
	-- methods
	setTargetModelInfo: (self: ActionQueue, targetModelInfo: ModelInfo.ModelInfo) -> (),
	getModelInfo: (self: ActionQueue) -> ModelInfo.ModelInfo?,
	addAction: (self: ActionQueue, action: Actions.Action) -> (),
	processQueue: (self: ActionQueue) -> (),
	flushQueue: (self: ActionQueue) -> (),
	destroy: (self: ActionQueue) -> (),
}

--[=[
	@class ActionQueue
	@server

	Replays a player's edit actions against the server's authoritative copy of their model.

	The client executes each action locally for instant feedback and mirrors it here, so the
	queue is the only thing that decides what the published asset actually contains. Actions
	drain synchronously in arrival order — [ActionQueue:flushQueue] is what publishing uses to
	be sure nothing is still pending.
]=]
local function ActionQueue(player: Player): ActionQueue
	local maid = Maid.new()
	local object = {} :: ActionQueue

	object.player = player
	object.queue = {}
	object.actionInProgress = false
	object.targetModelInfo = nil
	object.gotTargetModelInfo = maid:add(Signal.new())
	object.processingFinished = maid:add(Signal.new())
	object.maid = maid

	--[=[
		@within ActionQueue
		@param targetModelInfo ModelInfo -- the server's copy of the player's model

		Binds the model actions replay against, then drains anything that arrived before it
		was ready.
	]=]
	function object:setTargetModelInfo(targetModelInfo: ModelInfo.ModelInfo)
		self.targetModelInfo = targetModelInfo
		self.gotTargetModelInfo:Fire()

		self:processQueue()
	end

	--[=[
		@within ActionQueue
		@return ModelInfo? -- the bound model, or nil before [ActionQueue:setTargetModelInfo]
	]=]
	function object:getModelInfo(): ModelInfo.ModelInfo?
		return self.targetModelInfo
	end

	--[=[
		@within ActionQueue
		@param action Action -- an action already checked against [Actions.isKnownActionType]

		Queues an action and drains immediately if nothing else is mid-drain.
	]=]
	function object:addAction(action: Actions.Action)
		table.insert(self.queue, action)

		self:processQueue()
	end

	--[=[
		@within ActionQueue

		Drains the queue, skipping actions that fail validation against the current model
		state. Re-entrant calls return immediately — the in-flight drain picks up anything
		appended while it runs.
	]=]
	function object:processQueue()
		if self.actionInProgress then
			return
		end

		local targetModelInfo = self.targetModelInfo
		if not targetModelInfo then
			return
		end

		if #self.queue == 0 then
			return
		end

		self.actionInProgress = true

		while #self.queue > 0 do
			local action = table.remove(self.queue, 1) :: Actions.Action

			if not Actions.isValidAction(targetModelInfo, action) then
				warn(`[ActionQueue] Invalid '{action.actionType}' action from {self.player.Name}`)
				warn("[ActionQueue] Action metadata:", HttpService:JSONEncode(action.actionMetaData))
				continue
			end

			Actions.executeAction(targetModelInfo, action)
		end

		self.processingFinished:Fire()

		self.actionInProgress = false
	end

	--[=[
		@within ActionQueue
		@yields

		Blocks until every queued action has been applied. Publishing calls this first so the
		uploaded asset reflects every edit the player made.
	]=]
	function object:flushQueue()
		if not self.targetModelInfo then
			self.gotTargetModelInfo:Wait()
		end

		if self.actionInProgress then
			self.processingFinished:Wait()
		end

		if #self.queue > 0 then
			self:processQueue()
		end
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return ActionQueue

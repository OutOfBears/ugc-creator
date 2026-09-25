local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AttributeReplicator = require("./AttributeReplicator")
local Behaviors = require("./Utils/Behaviors")
local Observers = require(ReplicatedStorage.Packages.Observers)
local PooledConnection = require("./PooledConnection")
local Sift = require(ReplicatedStorage.Packages.Sift)
local Types = require("./Behavior/BehaviorTypes")

local IS_RUNNING = RunService:IsRunning()
local IS_SERVER = RunService:IsServer()

type BehaviorConfig<S> = Types.BehaviorConfig<S>
type BehaviorConstructor<T, S> = Types.BehaviorConstructor<T, S>
type Replicator<S> = Types.Replicator<S>
export type BehaviorBase<I> = Types.BehaviorBase<I>

-- Multiple behavior classes may share a single AttributeReplicator on the
-- same instance. We ref-count uses per instance so that only the last behavior
-- to be cleaned up actually destroys the replicator.
local replicatorRefCount: { [Instance]: number } = {}

local function acquireReplicator<S>(instance: Instance, state: S?): Replicator<S>?
	local replicator: Replicator<S>?

	if IS_SERVER then
		local initialState = if state ~= nil then Sift.Dictionary.copyDeep(state) else nil
		replicator = AttributeReplicator.new(instance, initialState)
	else
		local ok, result = pcall(function()
			return AttributeReplicator.waitForReplicator(instance):expect()
		end)

		if not ok or instance.Parent == nil then
			return nil
		end

		replicator = result
	end

	replicatorRefCount[instance] = (replicatorRefCount[instance] or 0) + 1
	return replicator
end

local function releaseReplicator(instance: Instance, replicator: Replicator<any>)
	local count = replicatorRefCount[instance]
	if not count then
		return
	end

	count -= 1

	if count <= 0 then
		replicatorRefCount[instance] = nil
		replicator:Destroy()
	else
		replicatorRefCount[instance] = count
	end
end

local function Behavior<T, S>(tag: string, class: BehaviorConstructor<T, S>, config: BehaviorConfig<S>?)
	local behaviorConfig: BehaviorConfig<S> = config or {}
	local additionalTags = behaviorConfig.additionalTags

	local instanceType = behaviorConfig.instanceType or "Instance"
	local replicated = behaviorConfig.replicated ~= false
	local ancestors = behaviorConfig.ancestors
	local state = behaviorConfig.state

	if not IS_RUNNING then
		return class
	end

	Behaviors.registerClass(tag, class :: any)

	Observers.observeTag(tag, function(instance: Instance)
		if not instance:IsA(instanceType) then
			return
		end

		local replicator: Replicator<S>? = if replicated then acquireReplicator(instance, state) else nil

		-- acquireReplicator returns nil on the client when the instance was
		-- removed (or untagged) while we were waiting for the replicator.
		if replicated and replicator == nil then
			return
		end

		if state then
			for key, value in state do
				if replicator.State[key] == nil then
					replicator:Set(key, value)
				end
			end
		end

		if additionalTags then
			for _, extraTag in additionalTags do
				instance:AddTag(extraTag)
			end
		end

		local behavior = class(instance, replicator)
		if not behavior then
			return
		end

		Behaviors.register(behavior :: any, class :: any, instance)

		local connections: { RBXScriptConnection } = {}

		if behavior.onStart then
			task.spawn(behavior.onStart, behavior)
		end

		if behavior.onHeartbeat then
			table.insert(
				connections,
				PooledConnection(RunService.Heartbeat):Connect(function(deltaTime: number)
					behavior:onHeartbeat(deltaTime)
				end)
			)
		end

		if behavior.onStepped then
			table.insert(
				connections,
				PooledConnection(RunService.Stepped):Connect(function(time: number, deltaTime: number)
					behavior:onStepped(time, deltaTime)
				end)
			)
		end

		if not IS_SERVER and behavior.onRenderStepped then
			table.insert(
				connections,
				PooledConnection(RunService.RenderStepped):Connect(function(deltaTime: number)
					behavior:onRenderStepped(deltaTime)
				end)
			)
		end

		return function()
			for _, connection in connections do
				connection:Disconnect()
			end

			Behaviors.remove(class :: any, instance)

			if behavior.destroy then
				behavior.destroy(behavior)
			end

			if additionalTags then
				for _, extraTag in additionalTags do
					instance:RemoveTag(extraTag)
				end
			end

			if replicator then
				releaseReplicator(instance, replicator)
			end
		end
	end, ancestors)

	return class
end

return Behavior

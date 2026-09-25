local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Promise = require(ReplicatedStorage.Shared.Modules.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)
local AttributeSerializer = require(script.AttributeSerializer)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)

local IS_SERVER = RunService:IsServer()

local allAttributeReplicator = {}
local replicatorCreated = Signal.new()
local replicatorDestroyed = Signal.new()

export type TypedInstance<T> = T & Instance

export type State<T> = T & {
	[string]: any,
}

--[=[
	@class AttributeReplicator

	Wraps a Roblox `Instance`'s attributes as a replicated state table. On the server,
	writes flow out to attributes; on the client, attribute changes flow back into `State`.
	One replicator is shared per instance (ref-counted) — created automatically for any
	instance tagged `Replicator`, or on demand via [AttributeReplicator.new].
]=]

--[=[
	@interface AttributeReplicator
	@within AttributeReplicator
	.State State<T> -- replicated state table mirroring the instance's attributes
	.Instance TypedInstance<I> -- the backing Roblox instance whose attributes are replicated
	.Changed Signal<string, any> -- fires with (name, value) whenever a state key changes
	.Destroying Signal<()> -- fires once when the replicator is being destroyed
	.Maid Maid -- owns the signals and attribute connections, cleaned on Destroy
]=]
export type AttributeReplicator<T, I> = {
	State: State<T>,
	Instance: TypedInstance<I>,
	Changed: Signal.Signal<string, any>,
	Destroying: Signal.Signal<()>,
	Maid: Maid.Maid,
	Destroy: (AttributeReplicator<T, I>) -> (),
	Set: (AttributeReplicator<T, I>, string, any) -> (),
	Get: <V>(AttributeReplicator<T, I>, string) -> V,
	GetStateChangedSignal: (AttributeReplicator<T, I>, string) -> Signal.Signal<any>,
	Hook: (AttributeReplicator<T, I>, any) -> (),
}

local function AttributeReplicator<T, I>(
	instance: TypedInstance<I>,
	state: State<T>?,
	tag: boolean?
): AttributeReplicator<T, I>
	local attributeChangedSignals = {}
	local self = {}

	self.Maid = Maid.new()
	self.State = {}
	self.Instance = instance
	self.Changed = Signal.new()
	self.Destroying = Signal.new()

	self.Maid:giveTask(self.Changed)
	self.Maid:giveTask(self.Destroying)
	self.Maid:giveTask(function()
		for _, signal in pairs(attributeChangedSignals) do
			signal:Destroy()
		end

		attributeChangedSignals = {}
	end)

	self.Maid:giveTask(self.Instance.AttributeChanged:Connect(function(name)
		debug.profilebegin("AttributeReplicator:AttributeChanged")
		local value = AttributeSerializer.readValue(self.Instance:GetAttribute(name))

		if self.State[name] == value and typeof(value) ~= "table" then
			debug.profileend()
			return
		end

		self.State[name] = value
		self.Changed:Fire(name, value)
		debug.profileend()
	end))
	self.Maid:giveTask(self.Changed:Connect(function(name, value)
		if attributeChangedSignals[name] then
			attributeChangedSignals[name]:Fire(value)
		end
	end))

	self.State = state or {}
	for name, value in instance:GetAttributes() do
		self.State[name] = AttributeSerializer.readValue(value)
	end

	if IS_SERVER then
		for name, value in pairs(self.State) do
			self.Instance:SetAttribute(name, AttributeSerializer.writeValue(value))
		end
	end

	function self:Destroy()
		if allAttributeReplicator[instance] then
			allAttributeReplicator[instance] = nil
		end

		self.Destroying:Fire()
		replicatorDestroyed:Fire(self.Instance, self)

		self.Maid:Destroy()
	end

	--[=[
		@within AttributeReplicator
		@param name string -- state key to write
		@param value any -- new value; replicated out to the attribute on the server
	]=]
	function self:Set(name: string, value: any)
		debug.profilebegin("AttributeReplicator:Set")
		if self.State[name] == value and typeof(value) ~= "table" then
			debug.profileend()
			return
		end

		self.State[name] = value
		self.Changed:Fire(name, value)

		if IS_SERVER then
			self.Instance:SetAttribute(name, AttributeSerializer.writeValue(value))
		end

		debug.profileend()
	end

	--[=[
		@within AttributeReplicator
		@param name string -- state key to read
		@return any -- the current value for that key
	]=]
	function self:Get(name: string)
		return self.State[name]
	end

	--[=[
		@within AttributeReplicator
		@param name string -- state key to watch
		@return Signal<any> -- fires with the new value whenever that key changes
	]=]
	function self:GetStateChangedSignal(name: string)
		if not attributeChangedSignals[name] then
			attributeChangedSignals[name] = Signal.new()
		end

		return attributeChangedSignals[name]
	end

	--[=[
		@within AttributeReplicator
		@param object any -- table to mirror state onto

		Copies the current state onto `object` and keeps its fields in sync as state changes.
	]=]
	function self:Hook(object: any)
		for name, value in self.State do
			object[name] = value
		end

		self.Maid:giveTask(self.Changed:Connect(function(name, value)
			object[name] = value
		end))
	end

	allAttributeReplicator[instance] = self
	replicatorCreated:Fire(instance, self)

	if tag then
		self.Instance:AddTag("Replicator")
		self.Maid:giveTask(function()
			self.Instance:RemoveTag("Replicator")
		end)
	end

	return self
end

--[=[
	@within AttributeReplicator
	@function getFromInstance
	@param instance Instance -- the instance to look up
	@return AttributeReplicator? -- the replicator backing that instance, if one exists
]=]
local function getFromInstance(instance: Instance)
	return allAttributeReplicator[instance]
end

--[=[
	@within AttributeReplicator
	@function getFromName
	@param name string -- instance name to search for
	@return AttributeReplicator? -- the first replicator whose instance has that name
]=]
local function getFromName(name: string)
	for _, replicator in pairs(allAttributeReplicator) do
		if replicator.Instance.Name == name then
			return replicator
		end
	end

	return nil
end

--[=[
	@within AttributeReplicator
	@function waitForReplicator
	@param instance Instance -- the instance whose replicator to await
	@return Promise -- resolves with the replicator once it is created for the instance
]=]
local function waitForReplicator(instance: Instance)
	local calledFrom = debug.traceback()

	return Promise.new(function(resolve, reject, onCancel)
		local thread
		local created
		local destroyed

		if allAttributeReplicator[instance] then
			resolve(allAttributeReplicator[instance])
			return
		end

		thread = task.delay(10, function()
			warn(`Potential infinite yield waiting for replicator: {instance:GetFullName()} from:\n\n{calledFrom}`)
		end)

		created = replicatorCreated:Connect(function(createdInstance, replicator)
			if createdInstance == instance then
				created:Disconnect()
				destroyed:Disconnect()
				resolve(replicator)
				task.cancel(thread)
			end
		end)

		destroyed = replicatorDestroyed:Connect(function(destroyedInstance)
			if destroyedInstance == instance then
				created:Disconnect()
				destroyed:Disconnect()
				task.cancel(thread)
				reject("Replicator destroyed before it was created (This shouldn't happen ever..)")
			end
		end)

		onCancel(function()
			created:Disconnect()
			destroyed:Disconnect()
			task.cancel(thread)
		end)
	end)
end

for _, instance in pairs(CollectionService:GetTagged("Replicator")) do
	task.spawn(AttributeReplicator, instance)
end

CollectionService:GetInstanceAddedSignal("Replicator"):Connect(function(instance)
	if allAttributeReplicator[instance] then
		return
	end

	AttributeReplicator(instance)
end)

CollectionService:GetInstanceRemovedSignal("Replicator"):Connect(function(instance)
	if allAttributeReplicator[instance] then
		allAttributeReplicator[instance]:Destroy()
	end
end)

return {
	waitForReplicator = waitForReplicator,
	getFromInstance = getFromInstance,
	getFromName = getFromName,
	--[=[
		@within AttributeReplicator
		@function new
		@param instance Instance -- the instance to back the replicator
		@param state State<any>? -- optional initial state to seed
		@return AttributeReplicator -- the new replicator, or the existing one for that instance
	]=]
	new = function(instance: Instance, state: State<any>?)
		if allAttributeReplicator[instance] then
			return allAttributeReplicator[instance]
		end

		return AttributeReplicator(instance, state, true)
	end,
}

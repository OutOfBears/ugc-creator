local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Shared.Modules.Promise)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require("../Behavior/BehaviorTypes")

type AnyBehavior = Types.AnyBehavior
type AnyBehaviorClass = Types.AnyBehaviorClass
type BehaviorClass<T> = Types.BehaviorClass<T>
type BehaviorConstructor<T, S> = Types.BehaviorConstructor<T, S>

local classRegistry: { [AnyBehaviorClass]: string } = {}
local behaviorsByClass: { [AnyBehaviorClass]: { [Instance]: AnyBehavior } } = {}
local behaviorsByInstance: { [Instance]: { [AnyBehaviorClass]: AnyBehavior } } = {}
local behaviorAdded = Signal.new()

local EMPTY_CLASS_MAP: { [Instance]: any } = table.freeze({})

--[=[
	@class Behaviors

	Query utility for the Behavior system. Resolves behaviors attached to
	instances through CollectionService tags, including behavior pairs — multiple
	behavior classes that share a single tag on the same instance. The Behavior
	factory registers and removes behaviors here through the `@private` framework
	hooks; feature code uses the public query surface.
]=]

--[=[
	@within Behaviors
	@private
	@param tag string -- the CollectionService tag the class attaches to
	@param class AnyBehaviorClass -- the behavior class to bind

	Binds a behavior class to its tag. Called once per class by the factory.
]=]
local function registerClass(tag: string, class: AnyBehaviorClass)
	local existing = classRegistry[class]

	assert(
		existing == nil or existing == tag,
		string.format("Class is already registered to tag %q (cannot re-register to %q)", existing or "", tag)
	)

	classRegistry[class] = tag
end

--[=[
	@within Behaviors
	@param class AnyBehaviorClass -- the behavior class to look up
	@return string? -- the tag the class is registered to, or nil
]=]
local function getTagFromClass(class: AnyBehaviorClass): string?
	return classRegistry[class]
end

--[=[
	@within Behaviors
	@param behavior AnyBehavior -- a live behavior to look up
	@return string? -- the tag the behavior's class is registered to, or nil

	Resolves the tag of an already-registered behavior. Used by the network fire
	path so a behavior can address its cross-realm pair without storing its tag.
]=]
local function getTagFromBehavior(behavior: AnyBehavior): string?
	local byClass = behaviorsByInstance[behavior.instance]
	if not byClass then
		return nil
	end

	for class, registered in byClass do
		if registered == behavior then
			return classRegistry[class]
		end
	end

	return nil
end

--[=[
	@within Behaviors
	@param tag string -- the tag to look up
	@return { AnyBehaviorClass } -- every behavior class registered to the tag
]=]
local function getClassesWithTag(tag: string): { AnyBehaviorClass }
	local classes: { AnyBehaviorClass } = {}

	for class, behaviorTag in classRegistry do
		if behaviorTag == tag then
			table.insert(classes, class)
		end
	end

	return classes
end

--[=[
	@within Behaviors
	@private
	@param behavior AnyBehavior -- the constructed behavior
	@param class AnyBehaviorClass -- the class the behavior was built from
	@param instance Instance -- the instance the behavior is attached to

	Records a live behavior in the registry and fires `behaviorAdded`.
]=]
local function register(behavior: AnyBehavior, class: AnyBehaviorClass, instance: Instance)
	assert(classRegistry[class], "Cannot register a behavior for a class that has not been registered")

	local byInstance = behaviorsByClass[class]
	if not byInstance then
		byInstance = {}
		behaviorsByClass[class] = byInstance
	end
	byInstance[instance] = behavior

	local byClass = behaviorsByInstance[instance]
	if not byClass then
		byClass = {}
		behaviorsByInstance[instance] = byClass
	end
	byClass[class] = behavior

	behaviorAdded:Fire(instance, class)
end

--[=[
	@within Behaviors
	@private
	@param class AnyBehaviorClass -- the class to remove
	@param instance Instance -- the instance to remove it from

	Drops a behavior from the registry and clears its tag from the instance.
]=]
local function remove(class: AnyBehaviorClass, instance: Instance)
	local byInstance = behaviorsByClass[class]
	if byInstance then
		byInstance[instance] = nil
		if next(byInstance) == nil then
			behaviorsByClass[class] = nil
		end
	end

	local byClass = behaviorsByInstance[instance]
	if byClass then
		byClass[class] = nil
		if next(byClass) == nil then
			behaviorsByInstance[instance] = nil
		end
	end

	local classTag = classRegistry[class]
	if classTag and instance:HasTag(classTag) then
		instance:RemoveTag(classTag)
	end
end

--[=[
	@within Behaviors
	@param instance Instance -- the instance to query
	@param class BehaviorConstructor<T, any> -- the behavior class to resolve
	@return BehaviorClass<T>? -- the behavior on the instance, or nil
]=]
local function getBehavior<T>(instance: Instance, class: BehaviorConstructor<T, any>): BehaviorClass<T>?
	local byClass = behaviorsByInstance[instance]
	return byClass and byClass[class] or nil
end

--[=[
	@within Behaviors
	@param instance Instance -- the instance to start searching from
	@param class BehaviorConstructor<T, any> -- the behavior class to resolve
	@return BehaviorClass<T>? -- the nearest behavior found walking up ancestors, or nil

	Walks up from `instance` through its ancestors and returns the first matching
	behavior. Useful for resolving the owning behavior from a descendant part.
]=]
local function findBehavior<T>(instance: Instance, class: BehaviorConstructor<T, any>): BehaviorClass<T>?
	local current: Instance? = instance

	while current do
		local behavior = getBehavior(current, class)
		if behavior then
			return behavior
		end

		current = current.Parent
	end

	return nil
end

--[=[
	@within Behaviors
	@param instance Instance -- the instance to query
	@param tag string -- the tag whose behaviors to collect
	@return { AnyBehavior } -- every behavior on the instance sharing the tag (a behavior pair)
]=]
local function getBehaviorsWithTag(instance: Instance, tag: string): { AnyBehavior }
	local behaviors: { AnyBehavior } = {}

	local byClass = behaviorsByInstance[instance]
	if byClass then
		for class, behavior in byClass do
			if classRegistry[class] == tag then
				table.insert(behaviors, behavior)
			end
		end
	end

	return behaviors
end

--[=[
	@within Behaviors
	@param instance Instance -- the instance to query
	@return { AnyBehavior } -- every behavior attached to the instance
]=]
local function getBehaviorsOnInstance(instance: Instance): { AnyBehavior }
	local behaviors: { AnyBehavior } = {}
	local byClass = behaviorsByInstance[instance]

	if byClass then
		for _, behavior in byClass do
			table.insert(behaviors, behavior)
		end
	end

	return behaviors
end

--[=[
	@within Behaviors
	@param class BehaviorConstructor<T, any> -- the behavior class to collect
	@return { BehaviorClass<T> } -- every live behavior of the class
]=]
local function getBehaviorsOfClass<T>(class: BehaviorConstructor<T, any>): { BehaviorClass<T> }
	local behaviors: { BehaviorClass<T> } = {}
	local byInstance = behaviorsByClass[class]

	if byInstance then
		for _, behavior in byInstance do
			table.insert(behaviors, behavior)
		end
	end

	return behaviors
end

--[=[
	@within Behaviors
	@param class BehaviorConstructor<T, any> -- the behavior class to map
	@return { [Instance]: BehaviorClass<T> } -- the live instance→behavior map for the class

	Returns the registry's own map for the class (a frozen empty table when none
	exist). Do not mutate the result.
]=]
local function getClassMap<T>(class: BehaviorConstructor<T, any>): { [Instance]: BehaviorClass<T> }
	return behaviorsByClass[class] or EMPTY_CLASS_MAP
end

--[=[
	@within Behaviors
	@param instance Instance -- the instance to resolve on
	@param class BehaviorConstructor<T, any> -- the behavior class to await
	@return Promise<BehaviorClass<T>> -- resolves once the behavior is attached, rejects if the instance is destroyed

	Resolves immediately if the behavior already exists, otherwise waits for it
	to be registered.
]=]
local function waitForBehavior<T>(
	instance: Instance,
	class: BehaviorConstructor<T, any>
): Promise.Promise<BehaviorClass<T>>
	return Promise.new(function(resolve, reject, onCancel)
		local behavior = getBehavior(instance, class)
		if behavior then
			resolve(behavior)
			return
		end

		local destroyed
		local connection

		destroyed = instance.Destroying:Once(function()
			destroyed:Disconnect()
			connection:Disconnect()
			reject("Instance has been destroyed")
		end)

		connection = behaviorAdded:Connect(function(addedInstance, addedClass)
			if addedInstance == instance and addedClass == class then
				connection:Disconnect()
				resolve(getBehavior(instance, class) :: BehaviorClass<T>)
			end
		end)

		onCancel(function()
			connection:Disconnect()
			reject("waitForBehavior was cancelled")
		end)
	end)
end

return {
	registerClass = registerClass,
	register = register,
	remove = remove,
	getTagFromClass = getTagFromClass,
	getTagFromBehavior = getTagFromBehavior,
	getClassesWithTag = getClassesWithTag,
	getBehavior = getBehavior,
	findBehavior = findBehavior,
	getBehaviorsWithTag = getBehaviorsWithTag,
	getBehaviorsOnInstance = getBehaviorsOnInstance,
	getBehaviorsOfClass = getBehaviorsOfClass,
	getClassMap = getClassMap,
	waitForBehavior = waitForBehavior,
}

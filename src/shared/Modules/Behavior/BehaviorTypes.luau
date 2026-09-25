local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttributeReplicator = require(ReplicatedStorage.Shared.Modules.AttributeReplicator)
local Promise = require(ReplicatedStorage.Shared.Modules.Promise)

export type BehaviorConfig<S> = {
	instanceType: string?,
	ancestors: { Instance }?,
	additionalTags: { string }?,
	replicated: boolean?,
	state: S?,
}

export type Replicator<S> = AttributeReplicator.AttributeReplicator<S, Instance>

export type BehaviorBase<I> = {
	instance: I & Instance,
	executables: { [string]: (...any) -> () }?,
	getBehavior: <T>(self: BehaviorBase<I>, class: (Instance, any?) -> T) -> T?,
	findBehavior: <T>(self: BehaviorBase<I>, class: (Instance, any?) -> T) -> T?,
	getBehaviorsWithTag: (self: BehaviorBase<I>, tag: string) -> { any },
	getBehaviorsOnInstance: (self: BehaviorBase<I>) -> { any },
	waitForBehavior: <T>(self: BehaviorBase<I>, class: (Instance, any?) -> T) -> Promise.Promise<T>,
	fireClient: (self: BehaviorBase<I>, player: Player?, method: string, ...any) -> (),
	fireServer: (self: BehaviorBase<I>, method: string, ...any) -> (),
	onStart: ((self: BehaviorBase<I>) -> ())?,
	onHeartbeat: ((self: BehaviorBase<I>, deltaTime: number) -> ())?,
	onStepped: ((self: BehaviorBase<I>, time: number, deltaTime: number) -> ())?,
	onRenderStepped: ((self: BehaviorBase<I>, deltaTime: number) -> ())?,
	destroy: ((self: BehaviorBase<I>) -> ())?,
}

export type BehaviorClass<T> = T & BehaviorBase<Instance>
export type BehaviorConstructor<T, S> = (instance: Instance, replicator: Replicator<S>?) -> BehaviorClass<T>

export type AnyBehavior = BehaviorClass<any>
export type AnyBehaviorClass = BehaviorConstructor<any, any>

return nil

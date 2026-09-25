local RunService = game:GetService("RunService")

local Behaviors = require("../Utils/Behaviors")
local Types = require("./BehaviorTypes")

local IS_SERVER = RunService:IsServer()
local Network: any = if IS_SERVER then require("../Network").server() else require("../Network").client()

--[=[
	@class BehaviorBase

	Base constructor for behaviors. A behavior's own constructor calls
	`BehaviorBase(instance, replicator)` to build its object already wired with the
	shared framework surface — `instance`, `replicator`, the query methods
	(`self:getBehavior`, `self:findBehavior`, `self:getBehaviorsWithTag`,
	`self:getBehaviorsOnInstance`, `self:waitForBehavior`) and realm networking
	(`self:fireClient` on the server, `self:fireServer` on the client) — then adds
	its own fields and returns it. Behaviors stay purely functional: there is no
	post-construction attaching by the framework, everything lives on the object.
]=]
local function BehaviorBase(instance: Instance, replicator: Types.Replicator<any>?): Types.BehaviorBase<Instance>
	local object = {} :: any

	object.instance = instance
	object.replicator = replicator

	--[=[
		@within BehaviorBase
		@param class BehaviorConstructor -- the behavior class to resolve
		@return BehaviorClass? -- the behavior of that class on this instance, or nil
	]=]
	function object:getBehavior(class: any): any
		return Behaviors.getBehavior(self.instance, class)
	end

	--[=[
		@within BehaviorBase
		@param class BehaviorConstructor -- the behavior class to resolve
		@return BehaviorClass? -- the nearest match walking up ancestors, or nil
	]=]
	function object:findBehavior(class: any): any
		return Behaviors.findBehavior(self.instance, class)
	end

	--[=[
		@within BehaviorBase
		@param tag string -- the tag whose behavior pair to resolve
		@return { any } -- every behavior sharing the tag on this instance
	]=]
	function object:getBehaviorsWithTag(tag: string): { any }
		return Behaviors.getBehaviorsWithTag(self.instance, tag)
	end

	--[=[
		@within BehaviorBase
		@return { any } -- every behavior on this instance
	]=]
	function object:getBehaviorsOnInstance(): { any }
		return Behaviors.getBehaviorsOnInstance(self.instance)
	end

	--[=[
		@within BehaviorBase
		@param class BehaviorConstructor -- the behavior class to await
		@return Promise -- resolves with the behavior once it attaches to this instance
	]=]
	function object:waitForBehavior(class: any): any
		return Behaviors.waitForBehavior(self.instance, class)
	end

	if IS_SERVER then
		--[=[
			@within BehaviorBase
			@server
			@param player Player? -- the target client, or nil to fire every client
			@param method string -- the executable to run on the client pair
		]=]
		function object:fireClient(player: Player?, method: string, ...: any)
			local tag = Behaviors.getTagFromBehavior(self)

			if player then
				Network.fireClient(player, "execute", self.instance, tag, method, ...)
			else
				Network.fireAllClients("execute", self.instance, tag, method, ...)
			end
		end
	else
		--[=[
			@within BehaviorBase
			@client
			@param method string -- the executable to run on the server pair
		]=]
		function object:fireServer(method: string, ...: any)
			local tag = Behaviors.getTagFromBehavior(self)
			Network.fire("execute", self.instance, tag, method, ...)
		end
	end

	return object
end

return BehaviorBase

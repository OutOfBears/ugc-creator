local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Behavior = require(ReplicatedStorage.Shared.Modules.Behavior)
local BehaviorBase = require(ReplicatedStorage.Shared.Modules.Behavior.BehaviorBase)
local CreationController = require("../Controllers/CreationController")

type BehaviorBase<I> = Behavior.BehaviorBase<I>

export type ClientCreationKiosk = BehaviorBase<Instance> & {
	-- methods
	destroy: (self: ClientCreationKiosk) -> (),
}

--[=[
	@class ClientCreationKiosk
	@client

	Client half of the world kiosk. Its server pair fires `open` at whoever clicked the kiosk,
	naming the blank to start; this hands that off to [CreationController].
]=]
local function ClientCreationKiosk(instance: Instance)
	local object = BehaviorBase(instance) :: ClientCreationKiosk

	object.executables = {
		open = function(blankName: string)
			CreationController.open(blankName)
		end,
	}

	function object:destroy() end

	return object
end

return Behavior("CreationKiosk", ClientCreationKiosk, { replicated = false })

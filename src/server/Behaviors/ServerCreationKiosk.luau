local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Behavior = require(ReplicatedStorage.Shared.Modules.Behavior)
local BehaviorBase = require(ReplicatedStorage.Shared.Modules.Behavior.BehaviorBase)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)

type BehaviorBase<I> = Behavior.BehaviorBase<I>

export type ServerCreationKiosk = BehaviorBase<Instance> & {
	-- vars
	blankName: string?,
	-- methods
	destroy: (self: ServerCreationKiosk) -> (),
}

local logger = Logger.new()

--[=[
	@class ServerCreationKiosk
	@server

	A world kiosk that opens the item creation editor on the player who clicked it.

	Author a `BlankName` attribute naming the blank the kiosk starts (`RobotModel`,
	`TShirtModel` or `HatModel`) — it is authoring-time data, so it stays a plain attribute
	rather than replicated behavior state.
]=]
local function ServerCreationKiosk(instance: Instance)
	local maid = Maid.new()
	local object = BehaviorBase(instance) :: ServerCreationKiosk

	object.blankName = instance:GetAttribute("BlankName") :: string?

	function object:onStart()
		if not self.blankName then
			logger:warn(`CreationKiosk '{instance:GetFullName()}' has no BlankName attribute`)
			return
		end

		local clickDetector = instance:FindFirstChildWhichIsA("ClickDetector", true)
		if not clickDetector then
			logger:warn(`CreationKiosk '{instance:GetFullName()}' has no ClickDetector`)
			return
		end

		maid:add(clickDetector.MouseClick:Connect(function(player: Player)
			self:fireClient(player, "open", self.blankName)
		end))
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return Behavior("CreationKiosk", ServerCreationKiosk, { replicated = false })

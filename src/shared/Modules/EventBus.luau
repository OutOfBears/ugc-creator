local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

local function EventBus<T>(): Bus<T>
	local events = Signal.new()
	local bus = {}

	function bus.connect(name: T, callback: (...any) -> ()): () -> ()
		local connection = events:Connect(function(event: any, ...)
			if event == name then
				callback(...)
			end
		end)

		return function()
			connection:Disconnect()
		end
	end

	function bus.fire(name: T, ...: any)
		events:Fire(name, ...)
	end

	function bus:destroy()
		events:Destroy()
	end

	return bus
end

export type Bus<T> = {
	connect: (name: T, callback: (...any) -> ()) -> () -> (),
	fire: (name: T, ...any) -> (),
	destroy: (self: Bus<T>) -> (),
}

return { new = EventBus }

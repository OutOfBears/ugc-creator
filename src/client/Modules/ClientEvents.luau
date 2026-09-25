local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventBus = require(ReplicatedStorage.Shared.Modules.EventBus)

export type ClientEvents = "add_input_context" | "remove_input_context"

return EventBus.new() :: EventBus.Bus<ClientEvents>

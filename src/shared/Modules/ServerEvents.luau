local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventBus = require(ReplicatedStorage.Shared.Modules.EventBus)

type ServerEvents = string

return EventBus.new() :: EventBus.Bus<ServerEvents>

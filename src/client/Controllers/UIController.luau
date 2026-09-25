local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local Types = require(ReplicatedStorage.Shared.Types)

local player = Players.LocalPlayer

local UIController = {} :: Types.Controller
UIController.priority = math.huge

function UIController.onInit() end

function UIController.onRun() end

return UIController

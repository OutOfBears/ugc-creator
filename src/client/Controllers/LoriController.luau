local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Lori = require(ReplicatedStorage.Packages.Lori)
local Types = require(ReplicatedStorage.Shared.Types)

local STUDIO_ONLY = false
local IS_STUDIO = RunService:IsStudio()

local LoriController = {} :: Types.Controller

local instance: any? = nil

function LoriController.onInit()
	do
		return
	end

	if STUDIO_ONLY and not IS_STUDIO then
		return
	end

	if not instance then
		instance = Lori.create()
	end

	instance:mount(nil, {
		studioOnly = STUDIO_ONLY,
		maxItems = 8,
		template = Lori.Templates.Performance,
	})
end

return LoriController

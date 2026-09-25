local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Types = require(ReplicatedStorage.Shared.Types)

local CoreGuiController = {} :: Types.Controller & {
	enableCoreGui: (coreGuiType: Enum.CoreGuiType) -> (),
	disableCoreGui: (coreGuiType: Enum.CoreGuiType) -> (),
	setCore: (coreType: string, coreValue: any) -> (),
}

local CORE_GUI_DEFAULTS = {
	[Enum.CoreGuiType.Backpack] = false,
	[Enum.CoreGuiType.Health] = true,
}

local function repeatUntilSuccess(action: () -> ())
	local success

	repeat
		success = pcall(action)
		if not success then
			task.wait()
		end
	until success
end

local function setCoreGuiEnabled(coreGuiType: Enum.CoreGuiType, enabled: boolean)
	repeatUntilSuccess(function()
		StarterGui:SetCoreGuiEnabled(coreGuiType, enabled)
	end)
end

local function setCore(coreType: string, coreValue: any)
	repeatUntilSuccess(function()
		StarterGui:SetCore(coreType, coreValue)
	end)
end

function CoreGuiController.onRun()
	for coreGuiType, enabled in CORE_GUI_DEFAULTS do
		setCoreGuiEnabled(coreGuiType, enabled)
	end

	setCore("ResetButtonCallback", false)
end

function CoreGuiController.enableCoreGui(coreGuiType: Enum.CoreGuiType)
	setCoreGuiEnabled(coreGuiType, true)
end

function CoreGuiController.disableCoreGui(coreGuiType: Enum.CoreGuiType)
	setCoreGuiEnabled(coreGuiType, false)
end

function CoreGuiController.setCore(coreType: string, coreValue: any)
	setCore(coreType, coreValue)
end

return CoreGuiController

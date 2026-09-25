local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Iris = require(ReplicatedStorage.Shared.Modules.Iris)
local Sift = require(ReplicatedStorage.Packages.Sift)

local config = {
	TextFont = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium),
	TextSize = 16,
}

return Sift.Dictionary.join({}, Iris.TemplateConfig.sizeClear, config)

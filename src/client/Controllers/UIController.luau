local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Types = require(ReplicatedStorage.Shared.Types)

local createElement = React.createElement
local createRoot = ReactRoblox.createRoot

local player = Players.LocalPlayer

local uiContainer: ScreenGui? = nil

--[=[
	@class UIController
	@client

	Mounts every ModuleScript in `Interfaces.Views` into its own `ScreenGui` under the `UI`
	ScreenGui in PlayerGui, passing that ScreenGui as the view's `playerGui` prop.
]=]
local UIController = {} :: Types.Controller
UIController.priority = math.huge

function UIController.onInit()
	uiContainer = Create("ScreenGui", {
		Name = "UI",
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui
end

function UIController.onRun()
	local views = ReplicatedStorage:WaitForChild("Interfaces"):FindFirstChild("Views")
	if not views then
		return
	end

	for _, view in views:GetChildren() do
		if not view:IsA("ModuleScript") then
			continue
		end

		local viewComponent = require(view) :: any
		local viewContainer = Create("ScreenGui", {
			Name = `{view.Name}View`,
			ResetOnSpawn = false,
			Parent = uiContainer,
		})

		local root = createRoot(viewContainer)
		root:render(createElement(viewComponent, {
			playerGui = viewContainer,
		}))
	end
end

return UIController

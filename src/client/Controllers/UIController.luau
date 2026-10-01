local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Types = require(ReplicatedStorage.Shared.Types)

local createElement = React.createElement
local createRoot = ReactRoblox.createRoot

local player = Players.LocalPlayer

local uiContainer: Folder? = nil

--[=[
	@class UIController
	@client

	Mounts every ModuleScript in `Interfaces.Views` into its own `ScreenGui` under a `UI` folder in
	PlayerGui, passing that ScreenGui as the view's `playerGui` prop. A folder rather than a
	ScreenGui holds them so each view's display order and insets act as a top-level ScreenGui's
	would; a view sets them with `useScreenGui`.
]=]
local UIController = {} :: Types.Controller
UIController.priority = math.huge

function UIController.onInit()
	uiContainer = Create("Folder", {
		Name = "UI",
		Parent = player:WaitForChild("PlayerGui"),
	}) :: Folder
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
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = uiContainer,
		})

		local root = createRoot(viewContainer)
		root:render(createElement(viewComponent, {
			playerGui = viewContainer,
		}))
	end
end

return UIController

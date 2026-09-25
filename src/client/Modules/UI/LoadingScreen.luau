local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Create = require(ReplicatedStorage.Shared.Modules.Create)

local player = Players.LocalPlayer

local screenGui: ScreenGui? = nil

--[=[
	@class LoadingScreen
	@client

	Full-screen cover shown while a blank's meshes and textures load.

	Roblox's template drove this off a `LoadingScreen` frame authored inside `StarterGui.ScreenGui`,
	which no project file mapped — the client just waited on it and hung if it was missing. It is
	built here instead so nothing in the place has to exist for the editor to open.
]=]
local LoadingScreen = {}

local function build(): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui")

	-- ResetOnSpawn is false so the gui outlives this module's state, which a live-sync reload
	-- (or a respawn) resets — without this, each reload would leave another cover behind.
	local existing = playerGui:FindFirstChild("LoadingScreen")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	local label = Create("TextLabel", {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "Loading…",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
	})

	return Create("ScreenGui", {
		Name = "LoadingScreen",
		DisplayOrder = 100,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.None,
		Enabled = false,
		Parent = playerGui,
		Children = {
			Create("Frame", {
				Name = "Cover",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Children = { label },
			}),
		},
	}) :: ScreenGui
end

--[=[
	@within LoadingScreen
	@param visible boolean -- whether to cover the screen

	Shows or hides the cover, creating it on first use.
]=]
function LoadingScreen.setVisible(visible: boolean)
	if not screenGui then
		screenGui = build()
	end

	(screenGui :: ScreenGui).Enabled = visible
end

--[=[
	@within LoadingScreen

	Tears the cover down. Safe to call when it was never shown.
]=]
function LoadingScreen.destroy()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return LoadingScreen

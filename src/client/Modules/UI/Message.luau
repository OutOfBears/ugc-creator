local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Create = require(ReplicatedStorage.Shared.Modules.Create)

local player = Players.LocalPlayer

--[=[
	@class Message
	@client

	A banner that drops in from the top of the screen, holds, and slides back out.
]=]
local Message = {}

--[=[
	@within Message
	@yields
	@param text string -- the message to show

	Shows a banner and blocks until it has slid back off screen.
]=]
function Message.create(text: string)
	local label = Create("TextLabel", {
		Size = UDim2.new(0, 400, 0, 100),
		Position = UDim2.new(0.5, -200, -0.2, 0),
		BackgroundColor3 = Color3.fromRGB(50, 50, 50),
		TextColor3 = Color3.fromRGB(200, 200, 200),
		Text = text,
		TextScaled = true,
		Children = {
			Create("UICorner", {
				CornerRadius = UDim.new(0, 15),
			}),
		},
	}) :: TextLabel

	local screenGui = Create("ScreenGui", {
		DisplayOrder = 10,
		Parent = player:WaitForChild("PlayerGui"),
		Children = { label },
	})

	local tweenIn = TweenService:Create(
		label,
		TweenInfo.new(1, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -200, 0, 0) }
	)
	tweenIn:Play()

	task.wait(10)

	local tweenOut = TweenService:Create(
		label,
		TweenInfo.new(1, Enum.EasingStyle.Bounce, Enum.EasingDirection.In),
		{ Position = UDim2.new(0.5, -200, -0.2, 0) }
	)
	tweenOut:Play()

	tweenOut.Completed:Wait()
	screenGui:Destroy()
end

return Message

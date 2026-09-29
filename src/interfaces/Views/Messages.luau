local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ClientAtoms = require(ReplicatedStorage.Client.Modules.ClientAtoms)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local React = require(ReplicatedStorage.Packages.React)

local useAtom = require("../Hooks/useAtom")
local useScreenGui = require("../Hooks/useScreenGui")

local createElement = React.createElement
local useEffect = React.useEffect
local useRef = React.useRef

local function Banner(props: { text: string })
	local labelRef = useRef(nil :: TextLabel?)

	useEffect(function()
		local label = labelRef.current
		if not label then
			return
		end

		local timing = CreationConfig.message
		local tweenIn = TweenService:Create(
			label,
			TweenInfo.new(timing.slideSeconds, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
			{ Position = timing.shownPosition }
		)
		tweenIn:Play()

		local tweenOut = TweenService:Create(
			label,
			TweenInfo.new(timing.slideSeconds, Enum.EasingStyle.Bounce, Enum.EasingDirection.In),
			{ Position = timing.hiddenPosition }
		)
		local slideOut = task.delay(timing.holdSeconds, function()
			tweenOut:Play()
		end)

		return function()
			task.cancel(slideOut)
			tweenIn:Cancel()
			tweenOut:Cancel()
		end
	end, {})

	return createElement("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(50, 50, 50),
		Position = CreationConfig.message.hiddenPosition,
		Size = UDim2.new(0, 400, 0, 100),
		Text = props.text,
		TextColor3 = Color3.fromRGB(200, 200, 200),
		TextScaled = true,
		ref = labelRef,
	}, {
		corner = createElement("UICorner", {
			CornerRadius = UDim.new(0, 15),
		}),
	})
end

--[=[
	@class Messages
	@client

	Banners that drop in from the top of the screen, hold, and slide back out, one per entry in
	`ClientAtoms.messages`.
]=]
local function Messages(props: { playerGui: ScreenGui })
	local messages = useAtom(ClientAtoms.messages)

	useScreenGui(props.playerGui, {
		DisplayOrder = 10,
	})

	local banners = {}
	for _, message in messages do
		banners[`message{message.id}`] = createElement(Banner, {
			text = message.text,
		})
	end

	return createElement(React.Fragment, nil, banners)
end

return Messages

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientAtoms = require(ReplicatedStorage.Client.Modules.ClientAtoms)
local CreationStrings = require(ReplicatedStorage.Shared.Data.CreationStrings)
local React = require(ReplicatedStorage.Packages.React)

local useAtom = require("../Hooks/useAtom")
local useScreenGui = require("../Hooks/useScreenGui")

local createElement = React.createElement

export type LoadingScreenProps = {
	playerGui: ScreenGui,
}

--[=[
	@class LoadingScreen
	@client

	Full-screen cover shown while a blank's meshes and textures load, from
	`ClientAtoms.loadingVisible`.
]=]
local function LoadingScreen(props: LoadingScreenProps)
	local visible = useAtom(ClientAtoms.loadingVisible)

	useScreenGui(props.playerGui, {
		DisplayOrder = 100,
		Enabled = visible,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
	})

	return createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, {
		label = createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.1),
			Text = CreationStrings.loading,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
		}),
	})
end

return LoadingScreen

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local EditHandle = require("../Components/EditHandle")
local SessionGate = require("./Creation/SessionGate")
local useAtom = require("../Hooks/useAtom")
local useAtomBinding = require("../Hooks/useAtomBinding")
local useCreationSession = require("../Hooks/useCreationSession")
local useScreenGui = require("../Hooks/useScreenGui")

local createElement = React.createElement

export type CreationWorldInputProps = {
	playerGui: ScreenGui,
}

local function WorldInput(props: CreationWorldInputProps)
	local session = useCreationSession()
	local creationInput = session:getCreationInput()
	local brushTool = session.brushTool
	local stickerTool = session.stickerTool
	local kitbashTool = session.kitbashTool

	local brushCaptureEnabled = useAtom(brushTool.captureEnabled)
	local stickerHandle = useAtomBinding(stickerTool.handle)
	local kitbashHandle = useAtomBinding(kitbashTool.handle)

	useScreenGui(props.playerGui, {
		DisplayOrder = 0,
	})

	return createElement(React.Fragment, nil, {
		cameraCapture = createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			[React.Event.InputChanged] = function(_: Frame, input: InputObject)
				creationInput:onCaptureScroll(input)
			end,
		}),
		brushCapture = createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = brushCaptureEnabled,
			ZIndex = 2,
			[React.Event.InputBegan] = function(_: Frame, input: InputObject, gameProcessedEvent: boolean)
				brushTool:onCaptureInputBegan(input, gameProcessedEvent)
			end,
		}),
		stickerHandle = createElement(EditHandle, {
			handle = stickerHandle,
			zIndex = 3,
			onInputBegan = function(kind, input: InputObject)
				stickerTool:beginHandleGesture(kind, input)
			end,
		}),
		kitbashHandle = createElement(EditHandle, {
			handle = kitbashHandle,
			zIndex = 4,
			onInputBegan = function(kind, input: InputObject)
				kitbashTool:beginHandleGesture(kind, input)
			end,
		}),
	})
end

--[=[
	@class CreationWorldInput
	@client

	The editor's full-screen input layer under the rest of the UI: the camera capture (scroll to
	zoom), the brush capture while painting on the model, and the sticker and add-on edit
	handles, stacked in that order so each sits over the ones before it.
]=]
local function CreationWorldInput(props: CreationWorldInputProps)
	return createElement(SessionGate, nil, {
		worldInput = createElement(WorldInput, props),
	})
end

return CreationWorldInput

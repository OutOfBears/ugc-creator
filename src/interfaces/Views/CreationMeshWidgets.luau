local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local SessionGate = require("./Creation/SessionGate")
local useAtom = require("../Hooks/useAtom")
local useAtomBinding = require("../Hooks/useAtomBinding")
local useCreationSession = require("../Hooks/useCreationSession")

local createElement = React.createElement

export type CreationMeshWidgetsProps = {
	playerGui: ScreenGui,
}

local function MeshWidgets(props: CreationMeshWidgetsProps)
	local widgets = useCreationSession().meshEditingWidgets
	local entries = useAtom(widgets.widgetEntries)
	local displays = useAtomBinding(widgets.widgetDisplays)
	local canvasSize = useAtomBinding(widgets.canvasSize)

	local children = {}
	for _, entry in entries do
		local name = entry.name
		local function display(read: (any) -> any, fallback: any)
			return displays:map(function(all)
				local current = all[name]
				return if current then read(current) else fallback
			end)
		end

		for lineIndex = 1, entry.lineCount do
			local function line(read: (any) -> any, fallback: any)
				return display(function(current)
					return read(current.lines[lineIndex])
				end, fallback)
			end

			children[`{name}Line{lineIndex}`] = createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.8,
				BorderSizePixel = 0,
				Position = line(function(current)
					return current.position
				end, UDim2.new()),
				Rotation = line(function(current)
					return current.rotation
				end, 0),
				Size = line(function(current)
					return current.size
				end, UDim2.new()),
				Visible = line(function(current)
					return current.visible
				end, false),
				ZIndex = 0,
			})
		end

		children[name] = createElement("ImageButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = CreationIcons.uiImages.WidgetHandle,
			ImageColor3 = CreationConfig.widgets.color,
			ImageTransparency = display(function(current)
				return if current.dragging then 1 else 0.5
			end, 0.5),
			Position = display(function(current)
				return current.position
			end, UDim2.new()),
			Size = UDim2.fromOffset(30, 30),
			Visible = display(function(current)
				return current.visible
			end, false),
			[React.Event.MouseButton1Down] = function()
				widgets:beginWidgetDrag(name)
			end,
		}, {
			circle = createElement("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = CreationIcons.uiImages.WidgetHandle,
				ImageColor3 = display(function(current)
					return if current.dragging then CreationConfig.widgets.draggingColor else Color3.new(1, 1, 1)
				end, Color3.new(1, 1, 1)),
				ImageTransparency = 0.1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(20, 20),
			}),
		})
	end

	local playerGui = props.playerGui:FindFirstAncestorOfClass("PlayerGui")
	if not playerGui then
		return nil
	end

	return ReactRoblox.createPortal(
		createElement("SurfaceGui", {
			Adornee = widgets.surfaceGuiPart,
			AlwaysOnTop = true,
			CanvasSize = canvasSize,
			ResetOnSpawn = false,
		}, children),
		playerGui
	)
end

--[=[
	@class CreationMeshWidgets
	@client

	The mesh-editing handles and their control bounds, drawn on a camera-facing SurfaceGui that
	[MeshEditingWidgets] positions each frame. Pressing a handle starts its drag.
]=]
local function CreationMeshWidgets(props: CreationMeshWidgetsProps)
	return createElement(SessionGate, nil, {
		meshWidgets = createElement(MeshWidgets, props),
	})
end

return CreationMeshWidgets

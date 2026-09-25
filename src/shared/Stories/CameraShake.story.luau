local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Shaker = require(ReplicatedStorage.Client.Modules.CameraShaker.Shaker)

local createElement = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

local PANEL_COLOR = Color3.fromRGB(28, 28, 32)
local FIELD_COLOR = Color3.fromRGB(48, 48, 54)
local BUTTON_GRADIENT_FROM = Color3.fromRGB(0, 200, 255)
local BUTTON_GRADIENT_TO = Color3.fromRGB(131, 118, 247)
local BUTTON_GRADIENT_FROM_SHIFTED = Color3.fromRGB(255, 0, 149)
local BUTTON_GRADIENT_TO_SHIFTED = Color3.fromRGB(247, 118, 120)
local TEXT_COLOR = Color3.fromRGB(235, 235, 235)

local LABEL_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local MONO_FONT = Font.new("rbxasset://fonts/families/RobotoMono.json")

local ROW_HEIGHT = 28
local TEXT_SIZE = 15

local DEFAULTS = {
	magnitude = "2.5",
	roughness = "4",
	fadeIn = "0.1",
	fadeOut = "0.75",
	sustainTime = "0",
	posX = "0.15",
	posY = "0.15",
	posZ = "0.15",
	rotX = "1",
	rotY = "1",
	rotZ = "1",
}

local PRESET_NAMES = {
	"Bump",
	"Explosion",
	"Earthquake",
	"BadTrip",
	"HandheldCamera",
	"Vibration",
	"RoughDriving",
}

local function round3(n: number): string
	return tostring(math.round(n * 1000) / 1000)
end

local function fieldBox(value: string, order: number, onCommit: (string) -> ())
	return createElement("TextBox", {
		Size = UDim2.new(1 / 3, -4, 1, 0),
		BackgroundColor3 = FIELD_COLOR,
		Text = value,
		ClearTextOnFocus = false,
		TextColor3 = TEXT_COLOR,
		FontFace = MONO_FONT,
		TextSize = TEXT_SIZE,
		LayoutOrder = order,
		[React.Event.FocusLost] = function(rbx: TextBox)
			onCommit(rbx.Text)
		end,
	}, {
		corner = createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
		padding = createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
	})
end

local function NumberField(props: {
	label: string,
	value: string,
	onChange: (string) -> (),
	layoutOrder: number,
})
	return createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = props.layoutOrder,
	}, {
		layout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		label = createElement("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.55, -4, 1, 0),
			Text = props.label,
			TextColor3 = TEXT_COLOR,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = LABEL_FONT,
			TextSize = TEXT_SIZE,
			LayoutOrder = 1,
		}),
		input = createElement("TextBox", {
			Size = UDim2.new(0.45, -4, 1, 0),
			BackgroundColor3 = FIELD_COLOR,
			Text = props.value,
			ClearTextOnFocus = false,
			TextColor3 = TEXT_COLOR,
			FontFace = MONO_FONT,
			TextSize = TEXT_SIZE,
			LayoutOrder = 2,
			[React.Event.FocusLost] = function(rbx: TextBox)
				props.onChange(rbx.Text)
			end,
		}, {
			corner = createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
			padding = createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
		}),
	})
end

local function VectorField(props: {
	label: string,
	x: string,
	y: string,
	z: string,
	onChange: (string, string) -> (),
	layoutOrder: number,
})
	return createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = props.layoutOrder,
	}, {
		layout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		label = createElement("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.4, -4, 1, 0),
			Text = props.label,
			TextColor3 = TEXT_COLOR,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = LABEL_FONT,
			TextSize = TEXT_SIZE,
			LayoutOrder = 1,
		}),
		fields = createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.6, -4, 1, 0),
			LayoutOrder = 2,
		}, {
			layout = createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			x = fieldBox(props.x, 1, function(text)
				props.onChange("X", text)
			end),
			y = fieldBox(props.y, 2, function(text)
				props.onChange("Y", text)
			end),
			z = fieldBox(props.z, 3, function(text)
				props.onChange("Z", text)
			end),
		}),
	})
end

local function GradientButton(props: {
	text: string,
	onClick: () -> (),
	gradientFrom: Color3,
	gradientTo: Color3,
	layoutOrder: number,
})
	return createElement("TextButton", {
		Size = UDim2.new(0, 0, 0, 40),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Text = "",
		AutoButtonColor = true,
		LayoutOrder = props.layoutOrder,
		[React.Event.MouseButton1Click] = props.onClick,
	}, {
		flex = createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		corner = createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
		gradient = createElement("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(props.gradientFrom, props.gradientTo),
		}),
		label = createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = props.text,
			TextColor3 = TEXT_COLOR,
			TextSize = 18,
			FontFace = LABEL_FONT,
		}),
		stroke = createElement("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Color = Color3.new(1, 1, 1),
			StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			Thickness = 0.05,
			Transparency = 0.6,
		}),
	})
end

local function PresetDropdown(props: {
	label: string,
	options: { string },
	selected: string?,
	onSelect: (string) -> (),
	layoutOrder: number,
})
	local open, setOpen = useState(false)

	local controlChildren: { [string]: any } = {
		header = createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = FIELD_COLOR,
			Text = if props.selected then props.selected else "Select preset…",
			TextColor3 = TEXT_COLOR,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = MONO_FONT,
			TextSize = TEXT_SIZE,
			AutoButtonColor = true,
			[React.Event.MouseButton1Click] = function()
				setOpen(function(prev)
					return not prev
				end)
			end,
		}, {
			corner = createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
			padding = createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			arrow = createElement("TextLabel", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Text = if open then "▲" else "▼",
				TextColor3 = TEXT_COLOR,
				FontFace = LABEL_FONT,
				TextSize = 10,
			}),
		}),
	}

	if open then
		local optionChildren: { [string]: any } = {
			layout = createElement("UIListLayout", {
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			corner = createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
			padding = createElement("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),
		}
		for index, name in props.options do
			optionChildren["option_" .. name] = createElement("TextButton", {
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				BackgroundColor3 = Color3.fromRGB(38, 38, 44),
				Text = name,
				TextColor3 = TEXT_COLOR,
				TextXAlignment = Enum.TextXAlignment.Left,
				FontFace = MONO_FONT,
				TextSize = TEXT_SIZE,
				AutoButtonColor = true,
				ZIndex = 6,
				LayoutOrder = index,
				[React.Event.MouseButton1Click] = function()
					props.onSelect(name)
					setOpen(false)
				end,
			}, {
				corner = createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
				padding = createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
				}),
			})
		end

		controlChildren.options = createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, 0, 1, 4),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(24, 24, 28),
			ZIndex = 6,
		}, optionChildren)
	end

	return createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = props.layoutOrder,
		ZIndex = 5,
	}, {
		layout = createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		label = createElement("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.55, -4, 1, 0),
			Text = props.label,
			TextColor3 = TEXT_COLOR,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = LABEL_FONT,
			TextSize = TEXT_SIZE,
			LayoutOrder = 1,
		}),
		control = createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.45, -4, 1, 0),
			LayoutOrder = 2,
		}, controlChildren),
	})
end

local function CameraShakePanel()
	local values, setValues = useState(DEFAULTS)
	local selectedPreset, setSelectedPreset = useState(nil :: string?)
	local shakerRef = useRef(nil)

	useEffect(function()
		local base = if workspace.CurrentCamera then workspace.CurrentCamera.CFrame else CFrame.identity

		local shaker = Shaker.new(Enum.RenderPriority.Camera.Value + 1, function(offset: CFrame)
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end

			if offset == CFrame.identity then
				base = camera.CFrame
			else
				camera.CFrame = base * offset
			end
		end)
		shaker:Start()
		shakerRef.current = shaker

		return function()
			shaker:Stop()
			shakerRef.current = nil
		end
	end, {})

	local function set(key: string)
		return function(text: string)
			setValues(function(prev)
				local updated = table.clone(prev)
				updated[key] = text
				return updated
			end)
		end
	end

	local function setAxis(prefix: string)
		return function(axis: string, text: string)
			setValues(function(prev)
				local updated = table.clone(prev)
				updated[prefix .. axis] = text
				return updated
			end)
		end
	end

	local function num(key: string): number
		return tonumber(values[key]) or 0
	end

	local function shake()
		local shaker = shakerRef.current
		if not shaker then
			return
		end

		shaker:ShakeOnce(
			num("magnitude"),
			num("roughness"),
			num("fadeIn"),
			num("fadeOut"),
			Vector3.new(num("posX"), num("posY"), num("posZ")),
			Vector3.new(num("rotX"), num("rotY"), num("rotZ"))
		)
	end

	local function sustain()
		local shaker = shakerRef.current
		if not shaker then
			return
		end

		local instance = shaker:StartShake(
			num("magnitude"),
			num("roughness"),
			num("fadeIn"),
			Vector3.new(num("posX"), num("posY"), num("posZ")),
			Vector3.new(num("rotX"), num("rotY"), num("rotZ"))
		)

		task.delay(num("sustainTime"), function()
			instance:StartFadeOut(num("fadeOut"))
		end)
	end

	local function selectPreset(name: string)
		setSelectedPreset(name)

		local preset = Shaker.Presets[name]()
		setValues(function(prev)
			local updated = table.clone(prev)
			updated.magnitude = round3(preset.Magnitude)
			updated.roughness = round3(preset.Roughness)
			updated.fadeIn = round3(preset.fadeInDuration)
			updated.fadeOut = round3(preset.fadeOutDuration)
			updated.posX = round3(preset.PositionInfluence.X)
			updated.posY = round3(preset.PositionInfluence.Y)
			updated.posZ = round3(preset.PositionInfluence.Z)
			updated.rotX = round3(preset.RotationInfluence.X)
			updated.rotY = round3(preset.RotationInfluence.Y)
			updated.rotZ = round3(preset.RotationInfluence.Z)
			return updated
		end)
	end

	return createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 340, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PANEL_COLOR,
	}, {
		corner = createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		padding = createElement("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		layout = createElement("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		title = createElement("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
			Text = "Camera Shake",
			TextColor3 = TEXT_COLOR,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = LABEL_FONT,
			TextSize = 20,
			LayoutOrder = 0,
		}),
		magnitude = createElement(NumberField, {
			label = "Magnitude",
			value = values.magnitude,
			onChange = set("magnitude"),
			layoutOrder = 3,
		}),
		roughness = createElement(NumberField, {
			label = "Roughness",
			value = values.roughness,
			onChange = set("roughness"),
			layoutOrder = 4,
		}),
		fadeIn = createElement(NumberField, {
			label = "Fade In",
			value = values.fadeIn,
			onChange = set("fadeIn"),
			layoutOrder = 5,
		}),
		fadeOut = createElement(NumberField, {
			label = "Fade Out",
			value = values.fadeOut,
			onChange = set("fadeOut"),
			layoutOrder = 6,
		}),
		sustainTime = createElement(NumberField, {
			label = "Sustain Time",
			value = values.sustainTime,
			onChange = set("sustainTime"),
			layoutOrder = 7,
		}),
		posInfluence = createElement(VectorField, {
			label = "Position Influence",
			x = values.posX,
			y = values.posY,
			z = values.posZ,
			onChange = setAxis("pos"),
			layoutOrder = 8,
		}),
		rotInfluence = createElement(VectorField, {
			label = "Rotation Influence",
			x = values.rotX,
			y = values.rotY,
			z = values.rotZ,
			onChange = setAxis("rot"),
			layoutOrder = 9,
		}),
		buttons = createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 10,
		}, {
			layout = createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			shake = createElement(GradientButton, {
				text = "Shake",
				onClick = shake,
				gradientFrom = BUTTON_GRADIENT_FROM,
				gradientTo = BUTTON_GRADIENT_TO,
				layoutOrder = 1,
			}),
			sustain = createElement(GradientButton, {
				text = "Sustain",
				onClick = sustain,
				gradientFrom = BUTTON_GRADIENT_FROM_SHIFTED,
				gradientTo = BUTTON_GRADIENT_TO_SHIFTED,
				layoutOrder = 2,
			}),
		}),
		preset = createElement(PresetDropdown, {
			label = "Preset",
			options = PRESET_NAMES,
			selected = selectedPreset,
			onSelect = selectPreset,
			layoutOrder = 1,
		}),
	})
end

local story = {
	react = React,
	reactRoblox = ReactRoblox,
	story = function()
		return createElement(CameraShakePanel)
	end,
}

return story

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ColorLayers = require(ReplicatedStorage.Shared.Data.ColorLayers)
local LayerColorCompositor = require("../Modules/LayerColorCompositor")
local LayerDecalPreview = require("../Modules/LayerDecalPreview")
local UILabs = require(ReplicatedStorage.Packages.UILabs)

-- Flip to false to A/B the EditableImage bake path against the decal fast-preview path.
local USE_MESH_TRICK = true
local CATALOG_NAME = "Fox"
local TARGET_NAME = "Fox"

local catalog = ColorLayers[CATALOG_NAME]

local controls = {}
for _, layer in catalog.layers do
	controls[layer.name] = UILabs.RGBA(Color3.new(1, 1, 1), 0)
end
for _, group in catalog.variantGroups do
	local optionNames = {}
	for _, groupOption in group.options do
		table.insert(optionNames, groupOption.name)
	end

	controls[group.name] = UILabs.RGBA(Color3.new(1, 1, 1), 0)
	controls[`{group.name} Variant`] = UILabs.Choose(optionNames, 1)
end

local function readState(ctrls: any): (LayerColorCompositor.SectionColors, LayerColorCompositor.VariantSelections)
	local sectionColors: LayerColorCompositor.SectionColors = {}
	for name, control in ctrls do
		if type(control) == "table" and control.Color then
			sectionColors[name] = { color = control.Color, alpha = control.Transparency }
		end
	end

	local variantSelections: LayerColorCompositor.VariantSelections = {}
	for _, group in catalog.variantGroups do
		local selected = ctrls[`{group.name} Variant`]
		for index, groupOption in group.options do
			if groupOption.name == selected then
				variantSelections[group.name] = index
				break
			end
		end
	end

	return sectionColors, variantSelections
end

local function resolveTargetPart(): BasePart
	local found = ReplicatedStorage:FindFirstChild(TARGET_NAME, true) or workspace:FindFirstChild(TARGET_NAME, true)

	if found then
		if found:IsA("BasePart") then
			return found:Clone()
		end

		local head = found:FindFirstChild("Head") or found:FindFirstChildWhichIsA("MeshPart", true)
		if head and head:IsA("BasePart") then
			return head:Clone()
		end
	end

	local placeholder = Instance.new("Part")
	placeholder.Name = TARGET_NAME
	placeholder.Anchored = true
	placeholder.Size = Vector3.one * 6

	return placeholder
end

return UILabs.CreateGenericStory({
	name = "LayerColor",
	summary = "Recolors a furry head from per-section tinted PNG layers. USE_MESH_TRICK stacks tinted"
		.. " decals for instant scrubbing; otherwise the layers bake into one EditableImage.",
	controls = controls,
}, function(props)
	local camera = workspace.CurrentCamera
	local target = resolveTargetPart()
	target.CFrame = if camera then camera.CFrame * CFrame.new(0, 0, -12) else CFrame.new(0, 5, 0)

	if USE_MESH_TRICK then
		target.Parent = workspace

		assert(target:IsA("MeshPart"), `LayerColor story needs a MeshPart named '{TARGET_NAME}' to preview on`)
		local preview = LayerDecalPreview(target, target, catalog)

		local connection = RunService.Heartbeat:Connect(function()
			local sectionColors, variantSelections = readState(props.controls)
			for name, sectionColor in sectionColors do
				preview:setSectionColor(name, sectionColor.color, sectionColor.alpha)
			end
			for groupName, optionIndex in variantSelections do
				preview:selectVariant(groupName, optionIndex)
			end
		end)

		return function()
			connection:Disconnect()
			preview:destroy()
			target:Destroy()
		end
	end

	local compositor = LayerColorCompositor(catalog)

	local imageLabel = Instance.new("ImageLabel")
	imageLabel.BackgroundTransparency = 1
	imageLabel.Size = UDim2.fromScale(0.8, 0.8)
	imageLabel.SizeConstraint = Enum.SizeConstraint.RelativeYY
	imageLabel.Position = UDim2.fromScale(0.5, 0.5)
	imageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	imageLabel.ImageContent = Content.fromObject(compositor:getEditableImage())
	imageLabel.Parent = props.target

	local lastSignature = ""
	local connection = RunService.Heartbeat:Connect(function()
		local sectionColors, variantSelections = readState(props.controls)

		local signature = ""
		for _, layer in catalog.layers do
			local sectionColor = sectionColors[layer.name]
			signature ..= if sectionColor then `{layer.name}:{sectionColor.color}:{sectionColor.alpha};` else ""
		end
		for groupName, optionIndex in variantSelections do
			signature ..= `{groupName}={optionIndex};`
		end

		if signature ~= lastSignature then
			lastSignature = signature
			compositor:compose(sectionColors, variantSelections)
		end
	end)

	return function()
		connection:Disconnect()
		compositor:destroy()
		imageLabel:Destroy()
		target:Destroy()
	end
end)

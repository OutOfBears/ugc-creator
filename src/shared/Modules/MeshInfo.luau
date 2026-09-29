local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AtlasUtil = require("./Utils/AtlasUtil")
local Blanks = require(ReplicatedStorage.Shared.Data.Blanks)
local Create = require("./Create")
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local Maid = require("./Maid")
local MeshUtils = require("./Utils/MeshUtils")

export type CageInfo = {
	cageEditableMesh: EditableMesh,
	wrapDeformer: WrapDeformer,

	deformedEditableMeshDirty: boolean,
	deformedEditableMesh: EditableMesh,

	initialVertexPositionsMap: { [number]: Vector3 },
	cageOrigin: CFrame,

	initialSize: Vector3,

	isWrapLayer: boolean?,
}

export type MeshPartInfo = {
	meshPart: MeshPart,

	cageInfo: CageInfo?,
	editableMesh: EditableMesh?,
	kitbashEditableMesh: EditableMesh?,

	initialCFrame: CFrame,
	scaleFactor: Vector3,
}

export type ModelMeshInfo = {
	[MeshPart]: MeshPartInfo,
}

export type EditableMeshMap = {
	[MeshPart]: EditableMesh,
}

export type ScaleFactorMap = {
	[MeshPart]: Vector3,
}

export type LineWidgetControl = {
	view: string,
	controlType: "Line",
	meshPart: MeshPart,

	controlP1: Vector3,
	controlP2: Vector3,

	startLinearProgress: number,
	linearProgress: number,
}

export type PlaneWidgetControl = {
	view: string,
	controlType: "Plane",
	meshPart: MeshPart,

	controlP1: Vector3,
	controlP2: Vector3,
	controlP3: Vector3,
	controlP4: Vector3,

	normal: Vector3,
}

export type WidgetControl = LineWidgetControl | PlaneWidgetControl

export type WidgetData = {
	name: string,
	widgetType: string,

	startPosition: Vector3,
	position: Vector3,
	radius: number,
	isSymmetrical: boolean,

	meshPart: MeshPart,

	mirroredPointName: string?,
	mirroredWidget: WidgetData?,
	isMirror: boolean?,

	deformsPartNames: { string },

	axisStart: Ray?,
	axisEnd: Vector3?,

	meshSpaceAxisStart: Ray?,
	meshSpaceAxisEnd: Vector3?,

	controls: { WidgetControl },
	activeControl: WidgetControl?,
}

export type ControlGroup = {
	name: string,

	widgets: {
		[string]: WidgetData,
	},
}

export type WidgetControlGroupMap = {
	[string]: ControlGroup,
}

export type MeshInfo = {
	-- vars
	maid: Maid.Maid,
	modelMeshInfo: ModelMeshInfo,
	widgetInfo: WidgetControlGroupMap,
	-- methods
	getModelMeshInfo: (self: MeshInfo) -> ModelMeshInfo,
	getDeformedEditableMesh: (self: MeshInfo, meshPart: MeshPart) -> EditableMesh,
	getEditableMesh: (self: MeshInfo, meshPart: MeshPart) -> EditableMesh,
	hasMeshPartByName: (self: MeshInfo, meshPartName: string) -> boolean,
	getMeshInfoByName: (self: MeshInfo, meshPartName: string) -> MeshPartInfo,
	markMeshPartDirty: (self: MeshInfo, meshPart: MeshPart) -> (),
	updateDeformedEditableMeshes: (self: MeshInfo) -> (),
	getScaleFactorMap: (self: MeshInfo) -> ScaleFactorMap,
	getEditableMeshMap: (self: MeshInfo) -> EditableMeshMap,
	getKitbashEditableMeshMap: (self: MeshInfo) -> EditableMeshMap,
	getControlGroup: (self: MeshInfo, controlGroupName: string) -> ControlGroup,
	hasWidgetByName: (self: MeshInfo, widgetName: string) -> boolean,
	getWidgetByName: (self: MeshInfo, widgetName: string) -> WidgetData,
	getAllWidgets: (self: MeshInfo) -> { [string]: WidgetData },
	destroy: (self: MeshInfo) -> (),
}

local function getWrapDeformer(meshPart: MeshPart): WrapDeformer
	local wrapDeformer = meshPart:FindFirstChildWhichIsA("WrapDeformer")
	if not wrapDeformer then
		wrapDeformer = Create("WrapDeformer", { Parent = meshPart }) :: WrapDeformer
	end

	return wrapDeformer :: WrapDeformer
end

local function setupBodyPart(meshPart: MeshPart, wrapTarget: WrapTarget): MeshPartInfo
	local wrapDeformer = getWrapDeformer(meshPart)

	local cageEditableMesh: EditableMesh =
		AssetService:CreateEditableMeshAsync(Content.fromUri(wrapTarget.CageMeshId), {
			FixedSize = true,
		})
	wrapDeformer:SetCageMeshContent(Content.fromObject(cageEditableMesh), wrapTarget.CageOrigin)

	local editableMesh: EditableMesh = wrapDeformer:CreateEditableMeshAsync()

	local initialCageVertexPositions = MeshUtils.getVertexPositions(cageEditableMesh)
	local min, max = MeshUtils.getVertexBounds(initialCageVertexPositions)
	local initialCageSize = max - min

	local initialVertexPositions = MeshUtils.getVertexPositions(editableMesh)
	local scaleFactor = MeshUtils.getScaleFactor(meshPart, initialVertexPositions)

	local partInfo: MeshPartInfo = {
		meshPart = meshPart,

		cageInfo = {
			cageEditableMesh = cageEditableMesh,
			wrapDeformer = wrapDeformer,

			initialVertexPositionsMap = initialCageVertexPositions,
			cageOrigin = wrapTarget.CageOrigin,

			initialSize = initialCageSize,

			deformedEditableMeshDirty = false,
			deformedEditableMesh = editableMesh,
		},

		initialCFrame = meshPart.CFrame,
		scaleFactor = scaleFactor,
	}

	return partInfo
end

local function remapUVsForKitbashAtlas(editableMesh: EditableMesh, atlasLayout: CreationConfig.AtlasLayout)
	for _, uvId in editableMesh:GetUVs() do
		local uv = editableMesh:GetUV(uvId)
		if uv then
			editableMesh:SetUV(uvId, AtlasUtil.remapUV(uv, atlasLayout.base))
		end
	end
end

local function applyEditableMesh(meshPart: MeshPart, editableMesh: EditableMesh)
	local pvOffset = meshPart.PivotOffset
	local newMeshPart = AssetService:CreateMeshPartAsync(Content.fromObject(editableMesh))

	newMeshPart.Size = meshPart.Size
	newMeshPart.CFrame = meshPart.CFrame
	newMeshPart.TextureContent = meshPart.TextureContent

	meshPart:ApplyMesh(newMeshPart)
	meshPart.PivotOffset = pvOffset

	newMeshPart:Destroy()
end

local function setupRigidMesh(meshPart: MeshPart, atlasLayout: CreationConfig.AtlasLayout?): MeshPartInfo
	local editableMesh = AssetService:CreateEditableMeshAsync(Content.fromUri(meshPart.MeshId), {
		FixedSize = atlasLayout == nil,
	})

	-- The paint tools project in studs, so a mesh authored in other units (e.g. a centimetre
	-- export) is brought to the part's stud scale before anything samples it.
	local authoredScale = MeshUtils.getScaleFactor(meshPart, MeshUtils.getVertexPositions(editableMesh))
	for _, vertexId in editableMesh:GetVertices() do
		editableMesh:SetPosition(vertexId, editableMesh:GetPosition(vertexId) / authoredScale)
	end

	if atlasLayout then
		remapUVsForKitbashAtlas(editableMesh, atlasLayout)
	end

	applyEditableMesh(meshPart, editableMesh)

	local initialVertexPositions = MeshUtils.getVertexPositions(editableMesh)
	local scaleFactor = MeshUtils.getScaleFactor(meshPart, initialVertexPositions)

	local partInfo: MeshPartInfo = {
		meshPart = meshPart,
		editableMesh = editableMesh,
		initialCFrame = meshPart.CFrame,
		scaleFactor = scaleFactor,
	}

	return partInfo
end

local function setupLayeredClothingPart(
	meshPart: MeshPart,
	wrapLayer: WrapLayer,
	atlasLayout: CreationConfig.AtlasLayout?
): MeshPartInfo
	local wrapDeformer = getWrapDeformer(meshPart)

	local editableMesh = AssetService:CreateEditableMeshAsync(Content.fromUri(meshPart.MeshId), {
		FixedSize = atlasLayout == nil,
	})
	if atlasLayout then
		remapUVsForKitbashAtlas(editableMesh, atlasLayout)
	end
	applyEditableMesh(meshPart, editableMesh)

	local outerCageEditableMesh: EditableMesh =
		AssetService:CreateEditableMeshAsync(Content.fromUri(wrapLayer.CageMeshId), {
			FixedSize = true,
		})
	local cageOrigin = wrapLayer.CageOrigin
	wrapDeformer:SetCageMeshContent(Content.fromObject(outerCageEditableMesh), cageOrigin)

	local wrapDeformerEditableMesh: EditableMesh = wrapDeformer:CreateEditableMeshAsync()

	local initialOuterCageVertexPositions = MeshUtils.getVertexPositions(outerCageEditableMesh)
	local min, max = MeshUtils.getVertexBounds(initialOuterCageVertexPositions)
	local initialCageSize = max - min
	local initialVertexPositions = MeshUtils.getVertexPositions(wrapDeformerEditableMesh)
	local scaleFactor = MeshUtils.getScaleFactor(meshPart, initialVertexPositions)

	local partInfo: MeshPartInfo = {
		meshPart = meshPart,
		cageInfo = {
			cageEditableMesh = outerCageEditableMesh,
			wrapDeformer = wrapDeformer,
			initialVertexPositionsMap = initialOuterCageVertexPositions,
			cageOrigin = cageOrigin,

			initialSize = initialCageSize,
			deformedEditableMeshDirty = false,
			deformedEditableMesh = wrapDeformerEditableMesh,

			isWrapLayer = true,
		},
		kitbashEditableMesh = editableMesh,
		initialCFrame = meshPart.CFrame,
		scaleFactor = scaleFactor,
	}

	return partInfo
end

local function trackEditableMeshes(maid: Maid.Maid, partInfo: MeshPartInfo)
	local cageInfo = partInfo.cageInfo
	if cageInfo then
		maid[partInfo.meshPart] = cageInfo.cageEditableMesh
		maid[cageInfo] = cageInfo.deformedEditableMesh
	elseif partInfo.editableMesh then
		maid[partInfo.meshPart] = partInfo.editableMesh
	end

	if partInfo.kitbashEditableMesh then
		maid[partInfo] = partInfo.kitbashEditableMesh
	end
end

local function setupModelMeshes(
	maid: Maid.Maid,
	model: Model,
	individualPartsNames: { [string]: boolean },
	atlasLayout: CreationConfig.AtlasLayout?
): ModelMeshInfo
	local newModelInfo: ModelMeshInfo = {}

	for _, descendant in model:GetDescendants() do
		if not descendant:IsA("MeshPart") then
			continue
		end

		if descendant.Name == "PrimaryPart" then
			continue
		end

		if not individualPartsNames[descendant.Name] then
			continue
		end

		local wrapTarget = descendant:FindFirstChildOfClass("WrapTarget")
		local wrapLayer = descendant:FindFirstChildOfClass("WrapLayer")
		if wrapTarget then
			newModelInfo[descendant] = setupBodyPart(descendant, wrapTarget)
		elseif wrapLayer then
			newModelInfo[descendant] = setupLayeredClothingPart(descendant, wrapLayer, atlasLayout)
		else
			newModelInfo[descendant] = setupRigidMesh(descendant, atlasLayout)
		end

		trackEditableMeshes(maid, newModelInfo[descendant])
	end

	return newModelInfo
end

local function buildWidgetControl(
	controlFolder: Folder,
	controlMeshPart: MeshPart,
	controlPoint: Part,
	worldMeshPart: MeshPart,
	startPosition: Vector3
): WidgetControl
	local controlTypeValue = controlFolder:FindFirstChild("ControlType") :: StringValue
	local controlType = controlTypeValue.Value

	if controlType == CreationConfig.controlTypes.line then
		local p1 = controlFolder:FindFirstChild("P1") :: BasePart
		local p2 = controlFolder:FindFirstChild("P2") :: BasePart

		local control: LineWidgetControl = {
			view = controlFolder.Name,
			controlType = CreationConfig.controlTypes.line :: "Line",
			meshPart = worldMeshPart,

			controlP1 = controlMeshPart.CFrame:PointToObjectSpace(p1.CFrame.Position),
			controlP2 = controlMeshPart.CFrame:PointToObjectSpace(p2.CFrame.Position),

			startLinearProgress = 0,
			linearProgress = 0,
		}

		local lineDirection = (control.controlP2 - control.controlP1)
		control.startLinearProgress = (startPosition - control.controlP1).Magnitude / lineDirection.Magnitude
		control.linearProgress = control.startLinearProgress

		return control
	elseif controlType == CreationConfig.controlTypes.plane then
		local p1 = controlFolder:FindFirstChild("P1") :: BasePart
		local p2 = controlFolder:FindFirstChild("P2") :: BasePart
		local p3 = controlFolder:FindFirstChild("P3") :: BasePart
		local p4 = controlFolder:FindFirstChild("P4") :: BasePart

		local normalObj = controlFolder:FindFirstChild("Normal") :: BasePart

		local control: PlaneWidgetControl = {
			view = controlFolder.Name,
			controlType = CreationConfig.controlTypes.plane :: "Plane",
			meshPart = worldMeshPart,

			controlP1 = controlMeshPart.CFrame:PointToObjectSpace(p1.CFrame.Position),
			controlP2 = controlMeshPart.CFrame:PointToObjectSpace(p2.CFrame.Position),
			controlP3 = controlMeshPart.CFrame:PointToObjectSpace(p3.CFrame.Position),
			controlP4 = controlMeshPart.CFrame:PointToObjectSpace(p4.CFrame.Position),

			normal = (normalObj.CFrame.Position - controlPoint.CFrame.Position).Unit,
		}

		return control
	end

	error("Invalid control type " .. controlType)
end

local function getControlPointValue(controlPoint: Part, valueName: string, defaultValue: any): any
	local value = controlPoint:FindFirstChild(valueName) :: any
	if value == nil then
		return defaultValue
	end

	return value.Value
end

local function buildWidgetData(
	controlMeshPart: MeshPart,
	controlPoint: Part,
	worldMeshPart: MeshPart,
	modelMeshInfo: ModelMeshInfo
): WidgetData
	local objectSpaceCFrame = controlMeshPart.CFrame:ToObjectSpace(controlPoint.CFrame)

	local widgetData: WidgetData = {
		name = controlPoint.Name,
		widgetType = getControlPointValue(controlPoint, "WidgetType", CreationConfig.widgetTypes.sphere),

		startPosition = objectSpaceCFrame.Position,
		position = objectSpaceCFrame.Position,
		radius = getControlPointValue(controlPoint, "Radius", 1),
		isSymmetrical = getControlPointValue(controlPoint, "IsSymmetrical", false),

		meshPart = worldMeshPart,

		mirroredPointName = getControlPointValue(controlPoint, "MirroredPoint", nil),
		mirroredWidget = nil,

		deformsPartNames = { worldMeshPart.Name },

		axisStart = nil,
		axisEnd = nil,

		meshSpaceAxisStart = nil,
		meshSpaceAxisEnd = nil,

		controls = {},
	}

	local deformsAdditionalPartsFolder = controlPoint:FindFirstChild("DeformsAdditionalParts")
	if deformsAdditionalPartsFolder ~= nil then
		for _, child in deformsAdditionalPartsFolder:GetChildren() do
			if child:IsA("StringValue") then
				widgetData.deformsPartNames[#widgetData.deformsPartNames + 1] = child.Value
			end
		end
	end

	local rayObject = controlPoint:FindFirstChild("Axis") :: BasePart?
	local axisEndObject = controlPoint:FindFirstChild("AxisEnd") :: BasePart?
	if rayObject ~= nil then
		local objectSpaceRayCFrame = controlMeshPart.CFrame:ToObjectSpace(rayObject.CFrame)
		widgetData.axisStart = Ray.new(objectSpaceRayCFrame.Position, objectSpaceRayCFrame.LookVector)
		if axisEndObject ~= nil then
			widgetData.axisEnd = controlMeshPart.CFrame:ToObjectSpace(axisEndObject.CFrame).Position
		end
	end

	for _, controlChild in controlPoint:GetChildren() do
		if not controlChild:IsA("Folder") then
			continue
		end

		local control =
			buildWidgetControl(controlChild, controlMeshPart, controlPoint, worldMeshPart, widgetData.startPosition)
		table.insert(widgetData.controls, control)
	end

	local partInfo: MeshPartInfo = modelMeshInfo[widgetData.meshPart]
	if
		widgetData.widgetType == CreationConfig.widgetTypes.cylinder
		or widgetData.widgetType == CreationConfig.widgetTypes.axisStretch
	then
		assert(widgetData.axisStart ~= nil, "Cylinder and AxisStretch widgets must have an axis defined")
		assert(partInfo.cageInfo, "CageInfo must exist for deformable mesh parts")

		widgetData.meshSpaceAxisStart = Ray.new(
			MeshUtils.localSpaceToEditableMeshSpace(
				widgetData.axisStart.Origin,
				worldMeshPart,
				partInfo.cageInfo.initialVertexPositionsMap
			),
			widgetData.axisStart.Direction
		)
	elseif widgetData.widgetType == CreationConfig.widgetTypes.muscle then
		assert(widgetData.axisStart ~= nil, "Muscle widgets must have an axis defined")
		assert(partInfo.cageInfo, "CageInfo must exist for deformable mesh parts")

		widgetData.meshSpaceAxisStart = Ray.new(
			MeshUtils.localSpaceToEditableMeshSpace(
				widgetData.axisStart.Origin,
				worldMeshPart,
				partInfo.cageInfo.initialVertexPositionsMap
			),
			widgetData.axisStart.Direction
		)
		widgetData.meshSpaceAxisEnd = MeshUtils.localSpaceToEditableMeshSpace(
			widgetData.axisEnd :: Vector3,
			worldMeshPart,
			partInfo.cageInfo.initialVertexPositionsMap
		)
	end

	return widgetData
end

local function createMirroredControls(currentControls: { WidgetControl }, targetMeshPart: MeshPart): { WidgetControl }
	local mirroredControls: { WidgetControl } = {}

	for _, widgetControl: WidgetControl in currentControls do
		local mirroredWidgetControl = {} :: any
		mirroredWidgetControl.view = widgetControl.view
		mirroredWidgetControl.controlType = widgetControl.controlType
		mirroredWidgetControl.meshPart = targetMeshPart
		mirroredWidgetControl.controlP1 = widgetControl.controlP1 * Vector3.new(-1, 1, 1)
		mirroredWidgetControl.controlP2 = widgetControl.controlP2 * Vector3.new(-1, 1, 1)

		if widgetControl.controlType == "Line" then
			mirroredWidgetControl.startLinearProgress = widgetControl.startLinearProgress
			mirroredWidgetControl.linearProgress = widgetControl.linearProgress
		elseif widgetControl.controlType == "Plane" then
			mirroredWidgetControl.controlP3 = widgetControl.controlP3 * Vector3.new(-1, 1, 1)
			mirroredWidgetControl.controlP4 = widgetControl.controlP4 * Vector3.new(-1, 1, 1)
			mirroredWidgetControl.normal = widgetControl.normal * Vector3.new(-1, 1, 1)
		end

		table.insert(mirroredControls, mirroredWidgetControl)
	end

	return mirroredControls
end

local function mirrorWidgetAxisProperties(
	mirroredWidget: WidgetData,
	widgetData: WidgetData,
	modelMeshInfo: ModelMeshInfo
)
	mirroredWidget.widgetType = widgetData.widgetType
	if widgetData.axisStart ~= nil then
		local rayOrigin = widgetData.axisStart.Origin * Vector3.new(-1, 1, 1)
		local rayDirection = widgetData.axisStart.Direction * Vector3.new(-1, 1, 1)
		mirroredWidget.axisStart = Ray.new(rayOrigin, rayDirection)

		if widgetData.axisEnd ~= nil then
			mirroredWidget.axisEnd = widgetData.axisEnd * Vector3.new(-1, 1, 1)
		end

		local partInfo: MeshPartInfo = modelMeshInfo[mirroredWidget.meshPart]
		if
			mirroredWidget.widgetType == CreationConfig.widgetTypes.cylinder
			or mirroredWidget.widgetType == CreationConfig.widgetTypes.axisStretch
		then
			assert(mirroredWidget.axisStart ~= nil, "Cylinder and AxisStretch widgets must have an axis defined")
			assert(partInfo.cageInfo, "CageInfo must exist for deformable mesh parts")

			mirroredWidget.meshSpaceAxisStart = Ray.new(
				MeshUtils.localSpaceToEditableMeshSpace(
					mirroredWidget.axisStart.Origin,
					mirroredWidget.meshPart,
					partInfo.cageInfo.initialVertexPositionsMap
				),
				mirroredWidget.axisStart.Direction
			)
		elseif mirroredWidget.widgetType == CreationConfig.widgetTypes.muscle then
			assert(mirroredWidget.axisStart ~= nil, "Muscle widgets must have an axis defined")
			assert(mirroredWidget.axisEnd ~= nil, "Muscle widgets must have an axis defined")
			assert(partInfo.cageInfo, "CageInfo must exist for deformable mesh parts")

			mirroredWidget.meshSpaceAxisStart = Ray.new(
				MeshUtils.localSpaceToEditableMeshSpace(
					mirroredWidget.axisStart.Origin,
					mirroredWidget.meshPart,
					partInfo.cageInfo.initialVertexPositionsMap
				),
				mirroredWidget.axisStart.Direction
			)
			mirroredWidget.meshSpaceAxisEnd = MeshUtils.localSpaceToEditableMeshSpace(
				mirroredWidget.axisEnd,
				mirroredWidget.meshPart,
				partInfo.cageInfo.initialVertexPositionsMap
			)
		end
	end
end

local function getMirroredWidget(controlGroup: ControlGroup, widgetData: WidgetData): (WidgetData, boolean)
	if widgetData.mirroredPointName and controlGroup.widgets[widgetData.mirroredPointName] then
		return controlGroup.widgets[widgetData.mirroredPointName], false
	end

	local virtualWidget: WidgetData = {
		name = widgetData.name .. "_Mirrored",
		widgetType = widgetData.widgetType,

		startPosition = widgetData.startPosition * Vector3.new(-1, 1, 1),
		position = widgetData.position * Vector3.new(-1, 1, 1),
		radius = widgetData.radius,
		isSymmetrical = widgetData.isSymmetrical,

		meshPart = widgetData.meshPart,

		isMirror = true,

		deformsPartNames = widgetData.deformsPartNames,

		axisStart = widgetData.axisStart,
		axisEnd = widgetData.axisEnd,

		controls = {},
	}

	return virtualWidget, true
end

local function linkMirroredWidgets(controlGroup: ControlGroup, modelMeshInfo: ModelMeshInfo)
	local newVirtualWidgets = {}

	for _, widgetData: WidgetData in controlGroup.widgets do
		if not widgetData.isSymmetrical then
			continue
		end

		if widgetData.isMirror then
			continue
		end

		local mirroredWidget: WidgetData, wasCreated = getMirroredWidget(controlGroup, widgetData)

		widgetData.mirroredWidget = mirroredWidget
		mirroredWidget.mirroredWidget = widgetData

		mirroredWidget.isMirror = true

		mirroredWidget.startPosition = widgetData.startPosition * Vector3.new(-1, 1, 1)
		mirroredWidget.position = widgetData.position * Vector3.new(-1, 1, 1)

		mirroredWidget.widgetType = widgetData.widgetType

		mirrorWidgetAxisProperties(mirroredWidget, widgetData, modelMeshInfo)

		mirroredWidget.controls = createMirroredControls(widgetData.controls, mirroredWidget.meshPart)

		if wasCreated then
			newVirtualWidgets[mirroredWidget.name] = mirroredWidget
		end
	end

	for _, widgetData: WidgetData in newVirtualWidgets do
		controlGroup.widgets[widgetData.name] = widgetData
	end
end

local function buildControlGroup(model: Model, controlGroupFolder: Folder, modelMeshInfo: ModelMeshInfo): ControlGroup
	local controlGroup: ControlGroup = {
		name = controlGroupFolder.Name,
		widgets = {},
	}

	for _, child in controlGroupFolder:GetChildren() do
		if child:IsA("MeshPart") == false then
			error("Invalid child of mesh edit control group!")
		end
		local meshPartName = child.Name

		local worldMeshPart = model:FindFirstChild(meshPartName, true) :: MeshPart
		if worldMeshPart == nil then
			error("Could not find in-world meshpart " .. meshPartName .. " for mesh edit controls!")
		end

		for _, controlPoint in child:GetChildren() do
			if controlPoint:IsA("Part") == false then
				continue
			end

			local widgetData = buildWidgetData(child :: MeshPart, controlPoint :: Part, worldMeshPart, modelMeshInfo)
			controlGroup.widgets[controlPoint.Name] = widgetData
		end
	end

	linkMirroredWidgets(controlGroup, modelMeshInfo)

	return controlGroup
end

local function buildWidgetInfo(
	model: Model,
	meshEditControlGroups: Folder,
	modelMeshInfo: ModelMeshInfo
): WidgetControlGroupMap
	local widgetControlGroupMap: WidgetControlGroupMap = {}

	for _, controlGroup in meshEditControlGroups:GetChildren() do
		widgetControlGroupMap[controlGroup.Name] = buildControlGroup(model, controlGroup :: Folder, modelMeshInfo)
	end

	return widgetControlGroupMap
end

--[=[
	@class MeshInfo

	Owns every EditableMesh behind an in-progress creation, plus the widget control groups that
	deform them.

	A part is either deformable — it carries a `cageInfo`, and edits go through its cage and
	WrapDeformer — or rigid, in which case it carries a plain `editableMesh` that is edited
	directly. Layered clothing is deformable *and* carries a `kitbashEditableMesh`, because
	kitbashing bypasses the deformer.
]=]
local function MeshInfo(model: Model, blank: Blanks.Blank): MeshInfo
	local maid = Maid.new()
	local object = {} :: MeshInfo

	object.maid = maid
	object.modelMeshInfo = setupModelMeshes(maid, model, blank.individualPartsNames, Blanks.getAtlasLayout(blank))
	object.widgetInfo = buildWidgetInfo(model, blank.meshEditControlGroups, object.modelMeshInfo)

	--[=[
		@within MeshInfo
		@return ModelMeshInfo -- every tracked MeshPart and its mesh data
	]=]
	function object:getModelMeshInfo(): ModelMeshInfo
		return self.modelMeshInfo
	end

	--[=[
		@within MeshInfo
		@param meshPart MeshPart -- a deformable part
		@return EditableMesh -- the deformed mesh, rebuilt from the cage if it went stale
	]=]
	function object:getDeformedEditableMesh(meshPart: MeshPart): EditableMesh
		local partInfo: MeshPartInfo = self.modelMeshInfo[meshPart]
		if not partInfo then
			error("MeshInfo not found for meshPart " .. meshPart.Name)
		end

		local cageInfo = partInfo.cageInfo
		assert(cageInfo, "CageInfo must exist for deformable meshPart " .. meshPart.Name)

		if cageInfo.deformedEditableMeshDirty then
			local deformedEditableMesh = cageInfo.wrapDeformer:CreateEditableMeshAsync() :: EditableMesh
			maid[cageInfo] = deformedEditableMesh
			cageInfo.deformedEditableMesh = deformedEditableMesh
			cageInfo.deformedEditableMeshDirty = false
		end

		return cageInfo.deformedEditableMesh
	end

	--[=[
		@within MeshInfo
		@param meshPart MeshPart -- any tracked part
		@return EditableMesh -- the mesh to edit, deformed or rigid depending on the part
	]=]
	function object:getEditableMesh(meshPart: MeshPart): EditableMesh
		local partInfo: MeshPartInfo = self.modelMeshInfo[meshPart]
		if not partInfo then
			error("MeshInfo not found for meshPart " .. meshPart.Name)
		end

		if partInfo.cageInfo then
			return self:getDeformedEditableMesh(meshPart)
		else
			assert(
				partInfo.editableMesh ~= nil,
				"EditableMesh or Deformed Mesh not found for meshPart " .. meshPart.Name
			)
			return partInfo.editableMesh
		end
	end

	--[=[
		@within MeshInfo
		@param meshPartName string -- the part name to look for
		@return boolean -- true if that part is tracked
	]=]
	function object:hasMeshPartByName(meshPartName: string): boolean
		for meshPart in self.modelMeshInfo do
			if meshPart.Name == meshPartName then
				return true
			end
		end

		return false
	end

	--[=[
		@within MeshInfo
		@param meshPartName string -- the part name to look for
		@return MeshPartInfo -- that part's mesh data

		Errors when the part is not tracked.
	]=]
	function object:getMeshInfoByName(meshPartName: string): MeshPartInfo
		for meshPart, partInfo: MeshPartInfo in self.modelMeshInfo do
			if meshPart.Name == meshPartName then
				return partInfo
			end
		end

		error("MeshInfo not found for meshPart " .. meshPartName)
	end

	--[=[
		@within MeshInfo
		@param meshPart MeshPart -- a deformable part whose cage just changed

		Marks the part's deformed mesh stale so the next read rebuilds it from the cage.
	]=]
	function object:markMeshPartDirty(meshPart: MeshPart)
		local partInfo: MeshPartInfo = self.modelMeshInfo[meshPart]
		if not partInfo then
			error("MeshInfo not found for meshPart " .. meshPart.Name)
		end

		assert(partInfo.cageInfo, "CageInfo must exist for deformable mesh parts")

		partInfo.cageInfo.deformedEditableMeshDirty = true
	end

	--[=[
		@within MeshInfo

		Rebuilds every stale deformed mesh, so the model matches its cages again.
	]=]
	function object:updateDeformedEditableMeshes()
		for meshPart, partInfo: MeshPartInfo in self.modelMeshInfo do
			if not partInfo.cageInfo then
				continue
			end

			self:getDeformedEditableMesh(meshPart)
		end
	end

	--[=[
		@within MeshInfo
		@return ScaleFactorMap -- each tracked part's mesh units per stud
	]=]
	function object:getScaleFactorMap(): ScaleFactorMap
		local scaleFactorMap: ScaleFactorMap = {}

		for meshPart, partInfo: MeshPartInfo in self.modelMeshInfo do
			scaleFactorMap[meshPart] = partInfo.scaleFactor
		end

		return scaleFactorMap
	end

	--[=[
		@within MeshInfo
		@return EditableMeshMap -- each tracked part's editable mesh, deformed where applicable
	]=]
	function object:getEditableMeshMap(): EditableMeshMap
		local editableMeshMap: EditableMeshMap = {}

		for meshPart, partInfo: MeshPartInfo in self.modelMeshInfo do
			if partInfo.cageInfo then
				editableMeshMap[meshPart] = partInfo.cageInfo.deformedEditableMesh
			else
				assert(
					partInfo.editableMesh ~= nil,
					"EditableMesh or Deformed Mesh not found for meshPart " .. meshPart.Name
				)
				editableMeshMap[meshPart] = partInfo.editableMesh
			end
		end

		return editableMeshMap
	end

	--[=[
		@within MeshInfo
		@return EditableMeshMap -- the mesh kitbash geometry is merged into, per tracked part

		Layered accessories kitbash into their own mesh rather than the deformed one; rigid
		accessories kitbash straight into their editable mesh.
	]=]
	function object:getKitbashEditableMeshMap(): EditableMeshMap
		local editableMeshMap: EditableMeshMap = {}

		for meshPart, partInfo: MeshPartInfo in self.modelMeshInfo do
			if partInfo.cageInfo then
				editableMeshMap[meshPart] = partInfo.kitbashEditableMesh :: EditableMesh
			else
				editableMeshMap[meshPart] = partInfo.editableMesh :: EditableMesh
			end
		end

		return editableMeshMap
	end

	--[=[
		@within MeshInfo
		@param controlGroupName string -- the control group to fetch
		@return ControlGroup -- that group and its widgets
	]=]
	function object:getControlGroup(controlGroupName: string): ControlGroup
		local controlGroup = self.widgetInfo[controlGroupName]
		if controlGroup == nil then
			error("Control group " .. controlGroupName .. " not found")
		end

		return controlGroup
	end

	--[=[
		@within MeshInfo
		@param widgetName string -- the widget to look for
		@return boolean -- true if any control group has it
	]=]
	function object:hasWidgetByName(widgetName: string): boolean
		for _, controlGroup in self.widgetInfo do
			if controlGroup.widgets[widgetName] then
				return true
			end
		end

		return false
	end

	--[=[
		@within MeshInfo
		@param widgetName string -- the widget to look for
		@return WidgetData -- that widget

		Errors when no control group has it.
	]=]
	function object:getWidgetByName(widgetName: string): WidgetData
		for _, controlGroup in self.widgetInfo do
			local widget = controlGroup.widgets[widgetName]
			if widget then
				return widget
			end
		end

		error("Widget " .. widgetName .. " not found")
	end

	--[=[
		@within MeshInfo
		@return { [string]: WidgetData } -- every widget across every control group, keyed by name
	]=]
	function object:getAllWidgets(): { [string]: WidgetData }
		local widgets = {}
		for _, controlGroup in self.widgetInfo do
			for _, widget in controlGroup.widgets do
				widgets[widget.name] = widget
			end
		end

		return widgets
	end

	function object:destroy()
		maid:doCleaning()
	end

	return object
end

return MeshInfo

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Actions = require(ReplicatedStorage.Shared.Modules.Actions)
local CameraManager = require("./CameraManager")
local Create = require(ReplicatedStorage.Shared.Modules.Create)
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local CreationIcons = require(ReplicatedStorage.Shared.Data.CreationIcons)
local CreationInput = require("./CreationInput")
local GeometryUtil = require(ReplicatedStorage.Shared.Modules.Utils.GeometryUtil)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local MeshInfo = require(ReplicatedStorage.Shared.Modules.MeshInfo)
local ModelDisplay = require("./ModelDisplay")
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)
local Network = require(ReplicatedStorage.Shared.Modules.Network).client()
local ToolInput = require("./ToolInput")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

type WidgetController = {
	widgetData: MeshInfo.WidgetData,

	widgetUI: ImageButton,

	isActive: boolean,
	controlUIMap: {
		[MeshInfo.WidgetControl]: { GuiObject },
	},
}

export type MeshEditingWidgets = {
	-- vars
	maid: Maid.Maid,
	modelInfo: ModelInfo.ModelInfo,
	modelDisplay: ModelDisplay.ModelDisplay,
	creationInput: CreationInput.CreationInput,
	cameraManager: CameraManager.CameraManager,
	surfaceGuiPart: Part,
	surfaceGui: SurfaceGui,
	widgets: { [string]: WidgetController },
	draggingWidget: WidgetController?,
	lastWidgetAction: Actions.Action?,
	widgetUnderMouse: ImageButton?,
	prevMousePos: (Vector2 | Vector3)?,
	-- methods
	bindRenderStepped: (self: MeshEditingWidgets) -> (),
	setupWidgets: (self: MeshEditingWidgets, controlGroupName: string) -> (),
	isWidgetVisibleInView: (self: MeshEditingWidgets, widgetController: WidgetController, viewName: string) -> boolean,
	drawLineBetweenPoints: (self: MeshEditingWidgets, frame: GuiObject, p1: Vector3, p2: Vector3) -> (),
	onWidgetMoved: (self: MeshEditingWidgets, widgetData: MeshInfo.WidgetData, newPosition: Vector3) -> (),
	getWidgetDataForPart: (self: MeshEditingWidgets, partName: string) -> WidgetController?,
	getActiveControlForWidget: (
		self: MeshEditingWidgets,
		widgetData: MeshInfo.WidgetData
	) -> MeshInfo.WidgetControl?,
	dragWidget: (self: MeshEditingWidgets, widgetController: WidgetController, input: InputObject) -> (),
	isShowingWidgets: (self: MeshEditingWidgets) -> boolean,
	hideWidgets: (self: MeshEditingWidgets) -> (),
	destroy: (self: MeshEditingWidgets) -> (),
}

local function createWidgetUI(maid: Maid.Maid, widgetData: MeshInfo.WidgetData, surfaceGui: SurfaceGui)
	local circle = Create("ImageLabel", {
		Size = UDim2.fromOffset(20, 20),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Image = CreationIcons.uiImages.WidgetHandle,
		BackgroundTransparency = 1,
		ImageTransparency = 0.1,
		Name = "Circle",
		Position = UDim2.fromScale(0.5, 0.5),
	})

	local widget = Create("ImageButton", {
		Size = UDim2.fromOffset(30, 30),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Image = CreationIcons.uiImages.WidgetHandle,
		BackgroundTransparency = 1,
		ImageColor3 = CreationConfig.widgets.color,
		ImageTransparency = 0.5,
		Name = widgetData.name,
		Children = { circle },
		Parent = surfaceGui,
	}) :: ImageButton

	maid:giveTask(widget)

	local controlUIMap = {}

	for _, control: MeshInfo.WidgetControl in widgetData.controls do
		if control.controlType == CreationConfig.controlTypes.line then
			local lineFrame = Create("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.8,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Name = "LineControl" .. control.view,
				ZIndex = 0,
				Parent = surfaceGui,
			})

			maid:giveTask(lineFrame)

			controlUIMap[control] = { lineFrame }
		elseif control.controlType == CreationConfig.controlTypes.plane then
			local controlUI = {}
			for _i = 1, 4 do
				local lineFrame = Create("Frame", {
					BorderSizePixel = 0,
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0.8,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Name = "PlaneControl" .. control.view,
					ZIndex = 0,
					Parent = surfaceGui,
				})

				maid:giveTask(lineFrame)
				controlUI[#controlUI + 1] = lineFrame
			end

			controlUIMap[control] = controlUI
		end
	end

	return widget, controlUIMap
end

local function snapWorldPointToControl(point: Vector3, control: MeshInfo.WidgetControl): Vector3
	if control.controlType == CreationConfig.controlTypes.line then
		local objectSpaceP1 = control.controlP1
		local objectSpaceP2 = control.controlP2
		local initialCFrame = control.meshPart.CFrame
		local worldP1 = initialCFrame:PointToWorldSpace(objectSpaceP1)
		local worldP2 = initialCFrame:PointToWorldSpace(objectSpaceP2)
		local worldRay = Ray.new(worldP1, (worldP2 - worldP1).Unit)
		local lineLength = (worldP2 - worldP1).Magnitude

		local closestPointOnRay = worldRay:ClosestPoint(point)

		if (worldRay.Origin - closestPointOnRay).Magnitude > lineLength then
			closestPointOnRay = worldRay.Origin + worldRay.Direction * lineLength
		end

		return closestPointOnRay
	elseif control.controlType == CreationConfig.controlTypes.plane then
		local planeControl = control :: MeshInfo.PlaneWidgetControl

		local objectSpaceNormal = planeControl.normal
		local initialCFrame = control.meshPart.CFrame
		local worldSpaceNormal = initialCFrame:VectorToWorldSpace(objectSpaceNormal)

		local polygonVerts = {
			initialCFrame:PointToWorldSpace(planeControl.controlP1),
			initialCFrame:PointToWorldSpace(planeControl.controlP2),
			initialCFrame:PointToWorldSpace(planeControl.controlP3),
			initialCFrame:PointToWorldSpace(planeControl.controlP4),
		}

		return GeometryUtil.closestPointInPolygon3d(worldSpaceNormal, point, polygonVerts)
	end

	return point
end

--[=[
	@class MeshEditingWidgets
	@client

	Draws the draggable mesh-editing handles and their control bounds on a camera-facing
	SurfaceGui, and turns a drag into widget-position actions for the server.
]=]
local function MeshEditingWidgets(
	modelInfo: ModelInfo.ModelInfo,
	modelDisplay: ModelDisplay.ModelDisplay,
	creationInput: CreationInput.CreationInput,
	cameraManager: CameraManager.CameraManager
): MeshEditingWidgets
	local maid = Maid.new()
	local object = {} :: MeshEditingWidgets

	object.maid = maid
	object.modelInfo = modelInfo
	object.modelDisplay = modelDisplay
	object.creationInput = creationInput
	object.cameraManager = cameraManager

	local camera = workspace.CurrentCamera

	local surfaceGuiPart = Create("Part", {
		Name = "MeshEditingWidgetPart",
		Transparency = 1,
		Anchored = true,
		Parent = workspace,
	}) :: Part

	-- Adornee is set after construction: Create parents Instance-valued properties into the new
	-- object, so passing it inline would reparent the part under the SurfaceGui.
	local surfaceGui = Create("SurfaceGui", {
		Name = "MeshEditingControls",
		ResetOnSpawn = false,
		CanvasSize = camera.ViewportSize,
		AlwaysOnTop = true,
		Parent = PlayerGui,
	}) :: SurfaceGui
	surfaceGui.Adornee = surfaceGuiPart

	maid:giveTask(surfaceGuiPart)
	maid:giveTask(surfaceGui)

	object.surfaceGuiPart = surfaceGuiPart
	object.surfaceGui = surfaceGui

	object.widgets = {}
	object.draggingWidget = nil
	object.lastWidgetAction = nil
	object.widgetUnderMouse = nil

	maid.surfaceGui = RunService.RenderStepped:Connect(function()
		local model = modelDisplay:getModel()
		local cameraCFrame = camera:GetRenderCFrame()
		local distance = (cameraCFrame.Position - model.PrimaryPart.Position).Magnitude
			- math.max(model:GetExtentsSize().X, model:GetExtentsSize().Z) / 2
		local viewportSize = camera.ViewportSize
		local fov = math.rad(camera.FieldOfView)
		local aspect = viewportSize.X / viewportSize.Y
		camera.HeadLocked = true

		local height = 2 * distance * math.tan(fov / 2)
		local width = height * aspect

		surfaceGuiPart.Size = Vector3.new(width, height, 0.1)
		surfaceGui.CanvasSize = camera.ViewportSize

		local newCFrame = cameraCFrame * CFrame.new(0, 0, -distance)
		surfaceGuiPart.CFrame = CFrame.lookAt(newCFrame.Position, cameraCFrame.Position + cameraCFrame.LookVector)
	end)

	--[=[
		@within MeshEditingWidgets

		Starts the per-frame pass that positions the widgets and their control bounds. Safe to
		call repeatedly; only the first call binds.
	]=]
	function object:bindRenderStepped()
		if maid.stepped then
			return
		end

		maid.stepped = RunService.Stepped:Connect(function()
			for _, widgetController: WidgetController in self.widgets do
				if self.draggingWidget == nil then
					if self:isWidgetVisibleInView(widgetController, modelDisplay:getCurrentView()) then
						widgetController.widgetUI.Visible = true
						local initialCFrame = widgetController.widgetData.meshPart.CFrame
						local widgetPos = initialCFrame:PointToWorldSpace(widgetController.widgetData.position)
						local vector, _onScreen = workspace.CurrentCamera:WorldToScreenPoint(widgetPos)
						local guiInset = GuiService:GetGuiInset()
						widgetController.widgetUI.Position = UDim2.fromOffset(vector.X, vector.Y + guiInset.Y)
						widgetController.widgetUI.Visible = widgetController.isActive

						local widgetCircle = widgetController.widgetUI:FindFirstChild("Circle") :: ImageLabel
						widgetCircle.ImageColor3 = Color3.new(1, 1, 1)
						widgetController.widgetUI.ImageTransparency = 0.5
					else
						widgetController.widgetUI.Visible = false
					end
				else
					if widgetController == self.draggingWidget then
						widgetController.widgetUI.Visible = true
						local initialCFrame = widgetController.widgetData.meshPart.CFrame
						local widgetPos = initialCFrame:PointToWorldSpace(widgetController.widgetData.position)
						local vector, _onScreen = workspace.CurrentCamera:WorldToScreenPoint(widgetPos)
						local guiInset = GuiService:GetGuiInset()
						widgetController.widgetUI.Position = UDim2.fromOffset(vector.X, vector.Y + guiInset.Y)

						local widgetCircle = widgetController.widgetUI:FindFirstChild("Circle") :: ImageLabel
						widgetCircle.ImageColor3 = CreationConfig.widgets.draggingColor
						widgetController.widgetUI.ImageTransparency = 1
					else
						local widgetCircle = widgetController.widgetUI:FindFirstChild("Circle") :: ImageLabel
						widgetCircle.ImageColor3 = Color3.new(1, 1, 1)
						widgetController.widgetUI.ImageTransparency = 0.5
						widgetController.widgetUI.Visible = false
					end
				end

				for _, control: MeshInfo.WidgetControl in widgetController.widgetData.controls do
					local controlUI = widgetController.controlUIMap[control]

					if widgetController ~= self.draggingWidget or control.view ~= modelDisplay:getCurrentView() then
						if controlUI then
							for _, uiElement in controlUI do
								uiElement.Visible = false
							end
						end

						continue
					end

					for _, uiElement in controlUI do
						uiElement.Visible = true
					end
					if control.controlType == CreationConfig.controlTypes.line then
						local p1 = control.controlP1
						local p2 = control.controlP2
						local lineLength = (p1 - p2).Magnitude
						local frame = controlUI[1]

						local ray = Ray.new(p1, (p2 - p1).Unit)
						local closestPointOnRay = ray:ClosestPoint(widgetController.widgetData.position)

						if (ray.Origin - closestPointOnRay).Magnitude > lineLength then
							closestPointOnRay = ray.Origin + ray.Direction * lineLength
						end

						local diff = widgetController.widgetData.position - closestPointOnRay
						p1 = p1 + diff
						p2 = p2 + diff

						local initialCFrame = widgetController.widgetData.meshPart.CFrame
						p1 = initialCFrame:PointToWorldSpace(p1)
						p2 = initialCFrame:PointToWorldSpace(p2)

						local screenP1 = workspace.CurrentCamera:WorldToScreenPoint(p1)
						local screenP2 = workspace.CurrentCamera:WorldToScreenPoint(p2)
						self:drawLineBetweenPoints(frame, screenP1, screenP2)
					elseif control.controlType == CreationConfig.controlTypes.plane then
						local planeControl = control :: MeshInfo.PlaneWidgetControl

						local initialCFrame = widgetController.widgetData.meshPart.CFrame
						local p1 = initialCFrame:PointToWorldSpace(planeControl.controlP1)
						local p2 = initialCFrame:PointToWorldSpace(planeControl.controlP2)
						local p3 = initialCFrame:PointToWorldSpace(planeControl.controlP3)
						local p4 = initialCFrame:PointToWorldSpace(planeControl.controlP4)

						local planeBoundingLines = controlUI

						local screenP1 = workspace.CurrentCamera:WorldToScreenPoint(p1)
						local screenP2 = workspace.CurrentCamera:WorldToScreenPoint(p2)
						local screenP3 = workspace.CurrentCamera:WorldToScreenPoint(p3)
						local screenP4 = workspace.CurrentCamera:WorldToScreenPoint(p4)

						self:drawLineBetweenPoints(planeBoundingLines[1], screenP1, screenP2)
						self:drawLineBetweenPoints(planeBoundingLines[2], screenP2, screenP3)
						self:drawLineBetweenPoints(planeBoundingLines[3], screenP3, screenP4)
						self:drawLineBetweenPoints(planeBoundingLines[4], screenP4, screenP1)
					end
				end
			end
		end)
	end

	--[=[
		@within MeshEditingWidgets
		@param controlGroupName string -- the control group to show, e.g. a face, head or body group

		Activates the widgets of one control group, creating any that do not exist yet, and
		frames the camera on the mesh parts they affect.
	]=]
	function object:setupWidgets(controlGroupName: string)
		for _, widgetController: WidgetController in self.widgets do
			widgetController.isActive = false
		end

		local meshInfo: MeshInfo.MeshInfo = self.modelInfo:getMeshInfo()

		local controlGroup: MeshInfo.ControlGroup = meshInfo:getControlGroup(controlGroupName)

		local affectedMeshParts: { BasePart } = {}

		for widgetName, widgetData: MeshInfo.WidgetData in controlGroup.widgets do
			local widgetController: WidgetController? = self.widgets[widgetName]
			if widgetController then
				table.insert(affectedMeshParts, widgetController.widgetData.meshPart)
				widgetController.isActive = true
				continue
			end

			if widgetData.isMirror then
				continue
			end

			local widget, controlUIMap = createWidgetUI(maid, widgetData, surfaceGui)

			widgetController = {
				widgetData = widgetData,
				isActive = true,

				widgetUI = widget,

				controlUIMap = controlUIMap,
			}

			maid:giveTask(widget.MouseButton1Down:Connect(function()
				if creationInput:tryGrabLock(self) == false then
					return
				end

				self.draggingWidget = widgetController
			end))

			maid:giveTask(widget.MouseEnter:Connect(function()
				self.widgetUnderMouse = widget
			end))

			maid:giveTask(widget.MouseLeave:Connect(function()
				if self.widgetUnderMouse == widget then
					self.widgetUnderMouse = nil
				end
			end))

			self.widgets[widgetName] = widgetController

			table.insert(affectedMeshParts, widgetData.meshPart)
		end

		local focusPoint = Vector3.zero
		for _, meshPart in affectedMeshParts do
			focusPoint = focusPoint + meshPart.CFrame.Position
		end
		focusPoint = focusPoint / #affectedMeshParts

		cameraManager:focusCameraOnParts(affectedMeshParts, focusPoint)

		self:bindRenderStepped()
	end

	--[=[
		@within MeshEditingWidgets
		@param widgetController WidgetController -- the widget to test
		@param viewName string -- the current view, as reported by ModelDisplay
		@return boolean -- true if any of the widget's controls belong to that view
	]=]
	function object:isWidgetVisibleInView(widgetController: WidgetController, viewName: string): boolean
		for _, control in widgetController.widgetData.controls do
			if control.view == viewName then
				return true
			end
		end

		return false
	end

	--[=[
		@within MeshEditingWidgets
		@param frame GuiObject -- the frame to stretch between the points
		@param p1 Vector3 -- first screen point
		@param p2 Vector3 -- second screen point
	]=]
	function object:drawLineBetweenPoints(frame: GuiObject, p1: Vector3, p2: Vector3)
		local guiInset = GuiService:GetGuiInset()
		local screenDiff = p1 - p2
		local screenMidpoint = (p1 + p2) / 2
		frame.Position = UDim2.fromOffset(screenMidpoint.X, screenMidpoint.Y + guiInset.Y)
		frame.Rotation = math.atan2(screenDiff.Y, screenDiff.X) * (180 / math.pi)
		frame.Size = UDim2.fromOffset((screenDiff.X ^ 2 + screenDiff.Y ^ 2) ^ 0.5, 2)
	end

	--[=[
		@within MeshEditingWidgets
		@param widgetData MeshInfo.WidgetData -- the widget that moved
		@param newPosition Vector3 -- its new object-space position

		Applies the move locally and keeps it as the pending action, which is sent to the
		server when the drag ends.
	]=]
	function object:onWidgetMoved(widgetData: MeshInfo.WidgetData, newPosition: Vector3)
		local updateWidgetPositionActionMetadata: { [string]: any } = {
			widgetName = widgetData.name,
			newPosition = newPosition,
		}

		local widgetControl = self:getActiveControlForWidget(widgetData)
		if widgetControl ~= nil and widgetControl.controlType == CreationConfig.controlTypes.line then
			local lineDirection = (widgetControl.controlP2 - widgetControl.controlP1)
			local closestLinePoint = GeometryUtil.closestPointOnSegment(
				widgetData.position,
				widgetControl.controlP1,
				widgetControl.controlP2
			)
			local controlLinearProgress = (closestLinePoint - widgetControl.controlP1).Magnitude
				/ lineDirection.Magnitude

			updateWidgetPositionActionMetadata.newLinearProgress = controlLinearProgress

			local activeControlIndex = nil
			for i, control in widgetData.controls do
				if control == widgetControl then
					activeControlIndex = i
					break
				end
			end

			updateWidgetPositionActionMetadata.newActiveControl = activeControlIndex
		end

		local updateWidgetPositionAction =
			Actions.createAction(Actions.ActionTypes.UpdateWidgetPosition, updateWidgetPositionActionMetadata)

		Actions.executeAction(self.modelInfo, updateWidgetPositionAction)

		self.lastWidgetAction = updateWidgetPositionAction
	end

	--[=[
		@within MeshEditingWidgets
		@param partName string -- name of a mesh part
		@return WidgetController? -- the widget driving that part, if there is one
	]=]
	function object:getWidgetDataForPart(partName: string): WidgetController?
		for _, widgetController: WidgetController in self.widgets do
			if widgetController.widgetData.meshPart.Name == partName then
				return widgetController
			end
		end

		return nil
	end

	--[=[
		@within MeshEditingWidgets
		@param widgetData MeshInfo.WidgetData -- the widget being dragged
		@return MeshInfo.WidgetControl? -- the control for the current view, else the last one found
	]=]
	function object:getActiveControlForWidget(widgetData: MeshInfo.WidgetData): MeshInfo.WidgetControl?
		local currentView = modelDisplay:getCurrentView()
		local outOfViewControl = nil
		for _, control in widgetData.controls do
			if control.view == currentView then
				return control
			end

			outOfViewControl = control
		end

		return outOfViewControl
	end

	--[=[
		@within MeshEditingWidgets
		@param widgetController WidgetController -- the widget being dragged
		@param input InputObject -- the input driving the drag

		Projects the pointer onto the widget's depth plane, snaps it to the widget's control
		and applies the move.
	]=]
	function object:dragWidget(widgetController: WidgetController, input: InputObject)
		local position = ToolInput.getInputPosition(input)
		if self.prevMousePos ~= Vector2.zero then
			local mouseHitPoint = LocalPlayer:GetMouse().Hit.Position
			local direction = (mouseHitPoint - workspace.CurrentCamera.CFrame.Position).Unit
			local widgetWorldPos =
				widgetController.widgetData.meshPart.CFrame:PointToWorldSpace(widgetController.widgetData.position)
			local depth = (workspace.CurrentCamera.CFrame.Position - widgetWorldPos).Magnitude
			local worldPoint = workspace.CurrentCamera.CFrame.Position + direction * depth

			local activeControl = self:getActiveControlForWidget(widgetController.widgetData)
			if activeControl then
				worldPoint = snapWorldPointToControl(worldPoint, activeControl)
			end

			local newPosition = widgetController.widgetData.meshPart.CFrame:PointToObjectSpace(worldPoint)

			self:onWidgetMoved(widgetController.widgetData, newPosition)
		end

		self.prevMousePos = position
	end

	--[=[
		@within MeshEditingWidgets
		@return boolean -- true while any widget is active
	]=]
	function object:isShowingWidgets(): boolean
		for _, widgetController: WidgetController in self.widgets do
			if widgetController.isActive == true then
				return true
			end
		end

		return false
	end

	--[=[
		@within MeshEditingWidgets

		Deactivates every widget without destroying it.
	]=]
	function object:hideWidgets()
		for _, widgetController: WidgetController in self.widgets do
			widgetController.isActive = false
		end
	end

	function object:destroy()
		maid:doCleaning()
	end

	maid.inputChanged = UserInputService.InputChanged:Connect(function(input)
		if
			object.draggingWidget ~= nil
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
				or (ToolInput.isVirtualCursor(input.UserInputType) and input.KeyCode == Enum.KeyCode.Thumbstick1)
			)
		then
			object:dragWidget(object.draggingWidget, input)
		end
	end)

	maid.inputEnded = UserInputService.InputEnded:Connect(function(input)
		if ToolInput.isVirtualCursor(input.UserInputType) and input.KeyCode ~= Enum.KeyCode.ButtonA then
			return
		end

		if object.draggingWidget then
			if object.lastWidgetAction then
				Network.fire("SubmitAction", object.lastWidgetAction)
				object.lastWidgetAction = nil
			end

			object.draggingWidget = nil

			local updateWidgetPositionAction = Actions.createAction(Actions.ActionTypes.UpdateAttachmentsPositions, {})

			Actions.executeAction(object.modelInfo, updateWidgetPositionAction)

			Network.fire("SubmitAction", updateWidgetPositionAction)
		end
	end)

	return object
end

return MeshEditingWidgets

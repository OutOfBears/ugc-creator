local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetUtil = require(ReplicatedStorage.Shared.Modules.Utils.AssetUtil)
local CameraManager = require("../CameraManager")
local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)
local ModelDisplay = require("../ModelDisplay")
local ModelInfo = require(ReplicatedStorage.Shared.Modules.ModelInfo)

local LocalPlayer = Players.LocalPlayer

local ACCESSORY_CLONE_NAME = "AccessoryClone"

export type PreviewTool = {
	-- vars
	modelInfo: ModelInfo.ModelInfo,
	cameraManager: CameraManager.CameraManager,
	modelDisplay: ModelDisplay.ModelDisplay,
	roxyModel: Model,
	roxyPreviewMarker: BasePart,
	playerAvatar: Model,
	playerAvatarPreviewMarker: BasePart,
	maid: Maid.Maid,
	-- methods
	setupRoxy: (self: PreviewTool) -> (),
	setupPlayerClone: (self: PreviewTool) -> (),
	removeExistingMatchingAccessories: (self: PreviewTool, body: Model) -> (),
	getPreviewModels: (self: PreviewTool) -> { Model },
	moveCameraToMarker: (self: PreviewTool, marker: BasePart) -> (),
	moveCameraToRoxy: (self: PreviewTool) -> (),
	moveCameraToPlayerAvatar: (self: PreviewTool) -> (),
	applyAccessoryToBodies: (self: PreviewTool) -> (),
	endPreview: (self: PreviewTool) -> (),
	destroy: (self: PreviewTool) -> (),
}

--[=[
	@class PreviewTool
	@client

	Previews an accessory on the default avatar and on the player's own avatar, each parked at
	its marker in the Workspace.
]=]
local function PreviewTool(
	modelInfo: ModelInfo.ModelInfo,
	cameraManager: CameraManager.CameraManager,
	modelDisplay: ModelDisplay.ModelDisplay
): PreviewTool
	local maid = Maid.new()
	local object = {} :: PreviewTool

	object.modelInfo = modelInfo
	object.cameraManager = cameraManager
	object.modelDisplay = modelDisplay
	object.maid = maid

	--[=[
		@within PreviewTool

		Clones the default preview avatar onto its marker.
	]=]
	function object:setupRoxy()
		local roxyModel = AssetUtil.resolve("PreviewModels/Roxy") :: Model

		self.roxyModel = maid:add(roxyModel:Clone())
		self.roxyModel.Parent = workspace

		self.roxyPreviewMarker = workspace:WaitForChild("PreviewPositionMarker1")
		self.roxyPreviewMarker.Transparency = 1

		self:removeExistingMatchingAccessories(self.roxyModel)

		self.roxyModel:PivotTo(CFrame.new(self.roxyPreviewMarker.Position))
	end

	--[=[
		@within PreviewTool

		Clones the local player's character onto its marker.
	]=]
	function object:setupPlayerClone()
		local playerAvatarModel = LocalPlayer.Character

		playerAvatarModel.Archivable = true
		self.playerAvatar = maid:add(playerAvatarModel:Clone())
		playerAvatarModel.Archivable = false

		self.playerAvatar.Parent = workspace
		self.playerAvatar.Name = "PlayerAvatarClone"

		self.playerAvatarPreviewMarker = workspace:WaitForChild("PreviewPositionMarker2")
		self.playerAvatarPreviewMarker.Transparency = 1

		self:removeExistingMatchingAccessories(self.playerAvatar)

		self.playerAvatar:PivotTo(CFrame.new(self.playerAvatarPreviewMarker.Position))
	end

	--[=[
		@within PreviewTool
		@param body Model -- the preview body to strip

		Removes accessories of the same type as the one being previewed so the preview isn't
		wearing two of them.
	]=]
	function object:removeExistingMatchingAccessories(body: Model)
		local model: Model = self.modelInfo:getModel()
		local accessory = model:FindFirstChildWhichIsA("Accessory")

		local humanoid = body:FindFirstChildWhichIsA("Humanoid") :: Humanoid
		local humanoidAccessories = humanoid:GetAccessories()
		for _, existingAccessory in humanoidAccessories do
			if existingAccessory.AccessoryType == accessory.AccessoryType then
				existingAccessory:Destroy()
			end
		end
	end

	--[=[
		@within PreviewTool
		@return { Model } -- the two preview bodies
	]=]
	function object:getPreviewModels(): { Model }
		return { self.roxyModel, self.playerAvatar }
	end

	--[=[
		@within PreviewTool
		@param marker BasePart -- the marker to frame

		Locks camera input and frames the given marker.
	]=]
	function object:moveCameraToMarker(marker: BasePart)
		self.cameraManager:setCameraInputLocked(true)
		local camera = workspace.CurrentCamera

		local cameraPosition = marker.Position + CreationConfig.camera.previewOffset
		local targetPosition = marker.Position

		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = CreationConfig.camera.previewFieldOfView
		camera.CFrame = CFrame.lookAt(cameraPosition, targetPosition)
	end

	--[=[
		@within PreviewTool
	]=]
	function object:moveCameraToRoxy()
		self:moveCameraToMarker(self.roxyPreviewMarker)
	end

	--[=[
		@within PreviewTool
	]=]
	function object:moveCameraToPlayerAvatar()
		self:moveCameraToMarker(self.playerAvatarPreviewMarker)
	end

	--[=[
		@within PreviewTool

		Attaches a clone of the creation's accessory to both preview bodies.
	]=]
	function object:applyAccessoryToBodies()
		if self.modelInfo:getCreationType() ~= CreationConfig.creationTypes.accessory then
			warn("Cannot apply non-accessory item to avatar for preview!")
			return
		end

		local model: Model = self.modelInfo:getModel()
		local accessory = model:FindFirstChildWhichIsA("Accessory")
		assert(accessory, "Model must contain an accessory.")

		for _, body in { self.roxyModel, self.playerAvatar } do
			local accessoryClone = accessory:Clone()
			accessoryClone.Name = ACCESSORY_CLONE_NAME
			local handle = accessoryClone:FindFirstChildWhichIsA("MeshPart")
			handle.Name = "Handle"
			handle.Anchored = false
			accessoryClone.Parent = body

			local humanoid = body:FindFirstChildWhichIsA("Humanoid") :: Humanoid
			humanoid:BuildRigFromAttachments()

			if body == self.roxyModel then
				-- Rigid accessories may carry a previewScale so they sit well on the default avatar.
				local previewScale = self.modelInfo:getPreviewScale() or 1
				handle.Size = handle.Size * previewScale
			end
		end
	end

	--[=[
		@within PreviewTool

		Strips the previewed accessory off both bodies and hands the camera back.
	]=]
	function object:endPreview()
		for _, body in { self.roxyModel, self.playerAvatar } do
			local accessory = body:FindFirstChild(ACCESSORY_CLONE_NAME)
			accessory:Destroy()
		end

		self.cameraManager:setCameraInputLocked(false)
		self.cameraManager:resetCamera()
	end

	function object:destroy()
		maid:doCleaning()
	end

	object:setupRoxy()
	object:setupPlayerClone()

	modelDisplay:trackPreviewModels({ object.roxyModel, object.playerAvatar })

	return object
end

return PreviewTool

local AccessoryUtils = require("./AccessoryUtils")
local Create = require("../Create")

--[=[
	@class AttachmentUtils

	Keeps an avatar model's attachments and rig in step with the mesh edits applied to it —
	re-deriving attachment positions from the WrapDeformers and rebuilding the R15 Motor6D tree.
]=]

--[=[
	@within AttachmentUtils
	@param model Model -- the avatar model to stamp

	Records every attachment's current position in an `OriginalPosition` value, so deformed
	positions can be recomputed from the authored ones rather than from the last deformation.
]=]
local function addOriginalPositions(model: Model)
	for _, attachment in model:GetDescendants() do
		if attachment:IsA("Attachment") then
			Create("Vector3Value", {
				Name = "OriginalPosition",
				Value = attachment.Position,
				Parent = attachment,
			})
		end
	end
end

--[=[
	@within AttachmentUtils
	@param model Model -- the avatar model to restore

	Puts every attachment back to its recorded position and clears the `OriginalPosition` value.
]=]
local function revertToOriginalPositions(model: Model)
	for _, attachment in model:GetDescendants() do
		if attachment:IsA("Attachment") then
			local originalPositionValue = attachment:FindFirstChild("OriginalPosition") :: Vector3Value?
			if originalPositionValue then
				attachment.Position = originalPositionValue.Value
				originalPositionValue:Destroy()
			end
		end
	end
end

--[=[
	@within AttachmentUtils
	@param model Model -- the avatar model to update

	Moves every non-rig attachment to where its authored position lands once the parent part's
	WrapDeformer is applied.
]=]
local function updateAccessoryAttachmentsPositions(model: Model)
	for _, attachment in model:GetDescendants() do
		if not attachment:IsA("Attachment") then
			continue
		end

		if attachment.Name:find("RigAttachment") then
			continue
		end

		local originalPositionValue = attachment:FindFirstChild("OriginalPosition") :: Vector3Value
		local originalPosition = originalPositionValue.Value

		local wrapDeformer = (attachment.Parent :: Instance):FindFirstChildWhichIsA("WrapDeformer")
		if not wrapDeformer then
			continue
		end

		local deformedPosition = wrapDeformer:GetDeformedCFrameAsync(CFrame.new(originalPosition)).Position
		attachment.Position = deformedPosition
	end
end

--[=[
	@within AttachmentUtils
	@param model Model -- the avatar model to update

	Snaps each rigid accessory's handle back onto the body attachment it belongs to.
]=]
local function moveAccessoriesToAttachmentPoints(model: Model)
	local accessories: { AccessoryUtils.AccessoryInfo } = AccessoryUtils.gatherAccessories(model)

	for _, accessoryInfo: AccessoryUtils.AccessoryInfo in accessories do
		local matchingAttachment = accessoryInfo.attachedPartAttachment
		local attachment = accessoryInfo.attachment
		accessoryInfo.handle.CFrame = (matchingAttachment.Parent :: BasePart).CFrame
			* matchingAttachment.CFrame
			* attachment.CFrame:Inverse()
	end
end

-- Built with Instance.new rather than Create: Create parents any Instance-valued property into
-- the new object, so Part0/Part1 would become children of the Motor6D and parenting it under
-- Part1 would then be circular.
local function buildJoint(parentAttachment: Attachment, partForJointAttachment: Attachment)
	local jointName = parentAttachment.Name:gsub("RigAttachment", "")

	local joint = Instance.new("Motor6D")
	joint.Name = jointName
	joint.Part0 = parentAttachment.Parent :: BasePart
	joint.Part1 = partForJointAttachment.Parent :: BasePart
	joint.C0 = parentAttachment.CFrame
	joint.C1 = partForJointAttachment.CFrame
	joint.Parent = partForJointAttachment.Parent
end

local function gatherSiblings(part: BasePart): { BasePart }
	local siblings = {}

	local searchLocations = {}
	table.insert(searchLocations, part.Parent)
	for _, child in (part.Parent :: Instance):GetChildren() do
		if child:IsA("Folder") then
			table.insert(searchLocations, child)
		end
	end

	if (part.Parent :: Instance):IsA("Folder") and (part.Parent :: Instance).Parent then
		table.insert(searchLocations, (part.Parent :: Instance).Parent)
		for _, child in ((part.Parent :: Instance).Parent :: Instance):GetChildren() do
			if child:IsA("Folder") and child ~= part.Parent then
				table.insert(searchLocations, child)
			end
		end
	end

	for _, searchLocation in searchLocations do
		for _, child in searchLocation:GetChildren() do
			if child ~= part and child:IsA("BasePart") then
				table.insert(siblings, child)
			end
		end
	end

	return siblings
end

local function buildRigFromAttachmentsInternal(last: BasePart?, part: BasePart)
	for _, attachment in part:GetChildren() do
		if attachment:IsA("Attachment") and string.find(attachment.Name, "RigAttachment") then
			for _, sibling in gatherSiblings(part) do
				if sibling ~= part and sibling ~= last then
					local matchingAttachment = sibling:FindFirstChild(attachment.Name) :: Attachment?
					if matchingAttachment then
						sibling.Anchored = false

						buildJoint(attachment, matchingAttachment)

						buildRigFromAttachmentsInternal(part, matchingAttachment.Parent :: BasePart)
					end
				end
			end
		end
	end
end

--[=[
	@within AttachmentUtils
	@param model Model -- the avatar model to rig

	Walks the `RigAttachment` pairs out from the LowerTorso and builds a Motor6D for each one.
]=]
local function buildRigFromAttachments(model: Model)
	local torso = model:FindFirstChild("Torso")
	assert(torso, "Model does not have a Torso Folder")
	local lowerTorso = torso:FindFirstChild("LowerTorso")
	assert(lowerTorso, "Model does not have a LowerTorso")

	buildRigFromAttachmentsInternal(nil, lowerTorso :: BasePart)
end

return {
	addOriginalPositions = addOriginalPositions,
	revertToOriginalPositions = revertToOriginalPositions,
	updateAccessoryAttachmentsPositions = updateAccessoryAttachmentsPositions,
	moveAccessoriesToAttachmentPoints = moveAccessoriesToAttachmentPoints,
	buildRigFromAttachments = buildRigFromAttachments,
}

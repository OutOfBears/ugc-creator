local Create = require("../Create")

--[=[
	@class AccessoryUtils

	Finds the accessories on an avatar model and keeps their handles sized and re-welded as the
	body underneath them is edited.
]=]

export type AccessoryInfo = {
	accessory: Accessory,
	attachment: Attachment,
	handle: MeshPart,

	attachedPart: BasePart,
	attachedPartAttachment: Attachment,
}

local function getMatchingAttachment(attachmentName: string, attachments: { Attachment }): Attachment?
	for _, attachment in attachments do
		if attachment.Name == attachmentName then
			return attachment
		end
	end

	return nil
end

--[=[
	@within AccessoryUtils
	@param model Model -- the avatar model to scan
	@return { AccessoryInfo } -- every rigid accessory, paired with the body attachment it hangs off

	Layered accessories are skipped — they are driven by their WrapLayer, not by an attachment.
]=]
local function gatherAccessories(model: Model): { AccessoryInfo }
	local accessories: { AccessoryInfo } = {}

	local nonAccessoryAttachments = {}
	for _, attachment in model:GetDescendants() do
		if not attachment:IsA("Attachment") then
			continue
		end

		if not attachment:FindFirstAncestorWhichIsA("Accessory") then
			table.insert(nonAccessoryAttachments, attachment)
		end
	end

	for _, accessory in model:GetDescendants() do
		if not accessory:IsA("Accessory") then
			continue
		end

		local handle = accessory:FindFirstChildWhichIsA("MeshPart")
		if not handle then
			continue
		end

		if handle:FindFirstChildWhichIsA("WrapLayer") then
			continue
		end

		local attachment = handle:FindFirstChildWhichIsA("Attachment")
		if not attachment then
			continue
		end

		local matchingAttachment = getMatchingAttachment(attachment.Name, nonAccessoryAttachments)
		if not matchingAttachment then
			continue
		end

		local accessoryInfo: AccessoryInfo = {
			accessory = accessory,
			attachment = attachment,
			handle = handle,

			attachedPart = matchingAttachment.Parent :: BasePart,
			attachedPartAttachment = matchingAttachment,
		}

		table.insert(accessories, accessoryInfo)
	end

	return accessories
end

--[=[
	@within AccessoryUtils
	@param model Model -- the avatar model to resize

	Shrinks each accessory handle to match the body scale type it is attached to, remembering the
	authored size in an `OriginalSize` value so it can be put back.
]=]
local function resizeAccessoriesForDisplay(model: Model)
	local accessories: { AccessoryInfo } = gatherAccessories(model)

	for _, accessoryInfo: AccessoryInfo in accessories do
		local attachedPart = accessoryInfo.attachedPart

		local avatarPartScaleType = attachedPart:FindFirstChild("AvatarPartScaleType") :: StringValue?
		if not avatarPartScaleType then
			continue
		end

		local scaleMultiplier = Vector3.new(1, 1, 1)
		if avatarPartScaleType.Value == "ProportionsNormal" then
			scaleMultiplier = Vector3.new(0.625, 0.625, 0.625)
		elseif avatarPartScaleType.Value == "ProportionsSlender" then
			scaleMultiplier = Vector3.new(0.59467172622681, 0.625, 0.59467172622681)
		else
			continue
		end

		local originalSizeValue = accessoryInfo.handle:FindFirstChild("OriginalSize") :: Vector3Value?
		if not originalSizeValue then
			originalSizeValue = Create("Vector3Value", {
				Name = "OriginalSize",
				Value = accessoryInfo.handle.Size,
				Parent = accessoryInfo.handle,
			}) :: Vector3Value
		end

		accessoryInfo.handle.Size = (originalSizeValue :: Vector3Value).Value * scaleMultiplier
	end
end

--[=[
	@within AccessoryUtils
	@param model Model -- the avatar model to stamp

	Records every accessory handle's current size in an `OriginalSize` value.
]=]
local function addOriginalSizes(model: Model)
	for _, accessory in model:GetDescendants() do
		if not accessory:IsA("Accessory") then
			continue
		end

		local handle = accessory:FindFirstChildWhichIsA("MeshPart")
		if not handle then
			continue
		end

		Create("Vector3Value", {
			Name = "OriginalSize",
			Value = handle.Size,
			Parent = handle,
		})
	end
end

--[=[
	@within AccessoryUtils
	@param model Model -- the avatar model to restore

	Puts every accessory handle back to its recorded size and clears the `OriginalSize` value.
]=]
local function revertToOriginalSizes(model: Model)
	for _, accessory in model:GetDescendants() do
		if not accessory:IsA("Accessory") then
			continue
		end

		local handle = accessory:FindFirstChildWhichIsA("MeshPart")
		if not handle then
			continue
		end

		local originalSizeValue = handle:FindFirstChild("OriginalSize") :: Vector3Value?
		if not originalSizeValue then
			continue
		end

		handle.Size = originalSizeValue.Value
		originalSizeValue:Destroy()
	end
end

local function findMatchingAttachment(character: Model, attachmentName: string): Attachment?
	for _, child in character:GetDescendants() do
		if child:IsA("Attachment") and child.Name == attachmentName then
			if not child:FindFirstAncestorOfClass("Accessory") then
				return child
			end
		end
	end

	return nil
end

local function equipLayeredAccessory(character: Model, layeredAccessory: Accessory)
	local accessoryAttachment = layeredAccessory:FindFirstChildWhichIsA("Attachment", true) :: Attachment

	local attachment = findMatchingAttachment(character, accessoryAttachment.Name) :: Attachment
	local attachmentPart = attachment.Parent :: BasePart
	local wrapTarget = attachmentPart:FindFirstChildWhichIsA("WrapTarget") :: WrapTarget

	local itemPart = layeredAccessory:FindFirstChildWhichIsA("BasePart", true) :: BasePart
	local wrapLayer = itemPart:FindFirstChildWhichIsA("WrapLayer", true) :: WrapLayer
	local handle = itemPart

	local worldaFromWrap = wrapTarget.ImportOriginWorld
	local wrapFromWorldb = wrapLayer.ImportOriginWorld:Inverse()
	local worldaFromWorldb = worldaFromWrap * wrapFromWorldb
	local worldb = (wrapLayer.Parent :: BasePart).CFrame
	handle.CFrame = (worldaFromWorldb * worldb)

	-- Instance.new, not Create: Create parents Instance-valued properties into the new object,
	-- which would make Part0/Part1 children of the weld instead of its endpoints.
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = attachmentPart
	weld.Parent = handle

	itemPart.Anchored = false
	layeredAccessory.Parent = character
end

--[=[
	@within AccessoryUtils
	@param model Model -- the avatar model to re-fit

	Re-welds every layered accessory onto the body it wraps, after the body underneath has moved.
]=]
local function reapplyLayeredClothing(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("WrapLayer") then
			local handle = descendant.Parent :: BasePart

			for _, child in handle:GetChildren() do
				if child:IsA("Weld") then
					child:Destroy()
				end
			end

			local accessory = handle.Parent :: Accessory

			equipLayeredAccessory(model, accessory)
		end
	end
end

return {
	gatherAccessories = gatherAccessories,
	resizeAccessoriesForDisplay = resizeAccessoriesForDisplay,
	addOriginalSizes = addOriginalSizes,
	revertToOriginalSizes = revertToOriginalSizes,
	reapplyLayeredClothing = reapplyLayeredClothing,
}

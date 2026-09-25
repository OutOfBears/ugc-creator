local function getCharacterParts(character: Model): { BasePart }
	local parts = {} :: { BasePart }

	for _, obj in character:GetChildren() do
		if obj:IsA("BasePart") then
			table.insert(parts, obj)
		end

		if obj:IsA("Accessory") then
			local handle = obj:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				table.insert(parts, handle)
			end
		end
	end

	return parts
end

local function toggleCharacterVisiblity(character: Model, visible: boolean)
	local head = character:FindFirstChild("Head")
	local face = head and head:FindFirstChildOfClass("Decal")

	for _, part in getCharacterParts(character) do
		part.LocalTransparencyModifier = visible and 0 or 1
	end

	if face then
		face.LocalTransparencyModifier = visible and 0 or 1
	end
end

local function setCharacterTransparency(character: Model | BasePart, transparency: number)
	if character:IsA("BasePart") then
		character.LocalTransparencyModifier = transparency
	end

	for _, desc in character:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.LocalTransparencyModifier = transparency
		end
	end
end

local function mergeDescriptions(base: HumanoidDescription, override: HumanoidDescription): HumanoidDescription
	local DESCRIPTION_PROPS = {
		"BackAccessory",
		"Face",
		"FaceAccessory",
		"FrontAccessory",
		"GraphicTShirt",
		"HairAccessory",
		"HatAccessory",
		"HeadColor",
		"LeftArmColor",
		"LeftLegColor",
		"NeckAccessory",
		"Pants",
		"RightArmColor",
		"RightLegColor",
		"Shirt",
		"ShouldersAccessory",
		"TorsoColor",
		"WaistAccessory",
	}

	local merged = base:Clone()

	for _, property in DESCRIPTION_PROPS do
		local value = override[property]
		if value and value ~= "" and value ~= 0 then
			merged[property] = value
		end
	end

	return merged
end

return {
	mergeDescriptions = mergeDescriptions,
	getCharacterParts = getCharacterParts,
	toggleCharacterVisiblity = toggleCharacterVisiblity,
	setCharacterTransparency = setCharacterTransparency,
}

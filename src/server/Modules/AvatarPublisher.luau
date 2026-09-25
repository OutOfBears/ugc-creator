local AvatarCreationService = game:GetService("AvatarCreationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AccessoryUtils = require(ReplicatedStorage.Shared.Modules.Utils.AccessoryUtils)
local AttachmentUtils = require(ReplicatedStorage.Shared.Modules.Utils.AttachmentUtils)
local CreationTokens = require(ReplicatedStorage.Shared.Data.CreationTokens)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

local ACCESSORY_TO_AVATAR_ASSET_TYPE = {
	[Enum.AccessoryType.TShirt] = Enum.AvatarAssetType.TShirtAccessory,
	[Enum.AccessoryType.Hat] = Enum.AvatarAssetType.Hat,
	[Enum.AccessoryType.Jacket] = Enum.AvatarAssetType.JacketAccessory,
	[Enum.AccessoryType.Pants] = Enum.AvatarAssetType.PantsAccessory,
	[Enum.AccessoryType.Shirt] = Enum.AvatarAssetType.ShirtAccessory,
	[Enum.AccessoryType.DressSkirt] = Enum.AvatarAssetType.DressSkirtAccessory,
	[Enum.AccessoryType.Sweater] = Enum.AvatarAssetType.SweaterAccessory,
	[Enum.AccessoryType.Shorts] = Enum.AvatarAssetType.ShortsAccessory,
	[Enum.AccessoryType.Back] = Enum.AvatarAssetType.BackAccessory,
	[Enum.AccessoryType.Face] = Enum.AvatarAssetType.FaceAccessory,
	[Enum.AccessoryType.Neck] = Enum.AvatarAssetType.NeckAccessory,
	[Enum.AccessoryType.Waist] = Enum.AvatarAssetType.WaistAccessory,
	[Enum.AccessoryType.Front] = Enum.AvatarAssetType.FrontAccessory,
	[Enum.AccessoryType.Hair] = Enum.AvatarAssetType.HairAccessory,
}

local UPLOAD_ACCESSORY_NAME = "AccessoryForUpload"

local logger = Logger.new()

--[=[
	@class AvatarPublisher
	@server

	Uploads a finished creation through `AvatarCreationService`.

	Publishing is gated on a per-universe token from [CreationTokens]; a universe with no entry
	cannot publish at all, and [AvatarPublisher.getPrice] reports `0` so the UI falls back to a
	plain "Publish" label.
]=]
local AvatarPublisher = {}

--[=[
	@within AvatarPublisher
	@param avatarAssetType Enum.AvatarAssetType? -- the accessory type, or nil for a full body
	@return string? -- the publish token, or nil if this universe cannot publish that type

	Resolves the token for this universe. Kept server-side so clients never have to hold the
	token table — they ask for a price and get a number back.
]=]
function AvatarPublisher.resolveToken(avatarAssetType: Enum.AvatarAssetType?): string?
	local universe = CreationTokens[game.GameId]
	if not universe then
		return nil
	end

	if avatarAssetType then
		return universe.accessories[avatarAssetType]
	end

	return universe.body
end

--[=[
	@within AvatarPublisher
	@yields
	@param avatarAssetType Enum.AvatarAssetType? -- the accessory type, or nil for a full body
	@return number -- the Robux price, or 0 when there is no token or the lookup fails

	A `0` here is the UI's cue to show "Publish" instead of a price.
]=]
function AvatarPublisher.getPrice(avatarAssetType: Enum.AvatarAssetType?): number
	local token = AvatarPublisher.resolveToken(avatarAssetType)
	if not token then
		return 0
	end

	local ok, result = pcall(function()
		return AvatarCreationService:GetBatchTokenDetailsAsync({ token })
	end)

	if not ok then
		return 0
	end

	local tokenData = result[1]

	return if tokenData then tokenData.Price or 0 else 0
end

local function reportResult(player: Player, resultEnum: Enum, result: any, resultMessage: string): (boolean, string)
	local values = resultEnum :: any

	if result == values.Success then
		logger:info(`Published item for {player.Name}, ItemId: {resultMessage}`)

		return true, `Successfully uploaded item! ItemId: {resultMessage}`
	end

	logger:warn(`Publish failed for {player.Name}: {result} — {resultMessage}`)

	-- Rethrown so it lands in the place's error dashboard, but only for outcomes the player
	-- cannot cause themselves — a declined prompt or a timeout is not a bug.
	if result ~= values.PermissionDenied and result ~= values.Timeout then
		task.spawn(error, `Failed to upload item. Result: {result} | Error: {resultMessage}`)
	end

	return false, `Failed to upload item. Result: {result} | Error: {resultMessage}`
end

local function prepareForUpload(modelToPublish: Model): (Instance?, Enum.AvatarAssetType?, string?)
	AccessoryUtils.revertToOriginalSizes(modelToPublish)
	AttachmentUtils.revertToOriginalPositions(modelToPublish)

	local assetToUpload, avatarAssetType, avatarAssetToken

	for _, meshPart in modelToPublish:GetDescendants() do
		if not meshPart:IsA("MeshPart") then
			continue
		end

		meshPart.Anchored = false

		local parent = meshPart.Parent
		if parent and parent:IsA("Accessory") then
			local accessoryType = parent.AccessoryType
			local mappedType = accessoryType and ACCESSORY_TO_AVATAR_ASSET_TYPE[accessoryType]

			if mappedType then
				local token = AvatarPublisher.resolveToken(mappedType)
				if token then
					local modelParent = Instance.new("Model")
					parent.Parent = modelParent
					parent.Name = UPLOAD_ACCESSORY_NAME

					assetToUpload = parent
					avatarAssetType = mappedType
					avatarAssetToken = token
				end
			end

			meshPart.Name = "Handle"
		elseif meshPart.Name ~= "PrimaryPart" then
			meshPart.TextureID = ""
		end

		local weldConstraint = meshPart:FindFirstChildOfClass("WeldConstraint")
		if weldConstraint then
			weldConstraint:Destroy()
		end

		if meshPart:FindFirstChildOfClass("SurfaceAppearance") then
			meshPart.TextureContent = Content.none
		end
	end

	return assetToUpload, avatarAssetType, avatarAssetToken
end

--[=[
	@within AvatarPublisher
	@yields
	@param player Player -- the creator, who gets the purchase prompt
	@param modelToPublish Model -- a clone of the server's authoritative model, consumed by this call
	@return boolean -- true if the upload succeeded
	@return string -- a message to show the player either way

	Strips the editing scaffolding off the model, then prompts the player to buy and publish it.
	Uploads as an accessory when the model contains a publishable `Accessory`, otherwise as a
	full avatar built from its `HumanoidDescription`.
]=]
function AvatarPublisher.publish(player: Player, modelToPublish: Model): (boolean, string)
	local assetToUpload, avatarAssetType, avatarAssetToken = prepareForUpload(modelToPublish)

	if assetToUpload then
		local ok, result, resultMessage = pcall(function()
			return AvatarCreationService:PromptCreateAvatarAssetAsync(
				avatarAssetToken,
				player,
				assetToUpload,
				avatarAssetType
			)
		end)

		if not ok then
			logger:warn(`Accessory upload errored for {player.Name}: {result}`)

			return false, `Failed to upload asset. Reason: {result}`
		end

		return reportResult(player, Enum.PromptCreateAssetResult, result, resultMessage)
	end

	local humanoidDescription = modelToPublish:FindFirstChildWhichIsA("HumanoidDescription")
	local bodyToken = AvatarPublisher.resolveToken(nil)

	local ok, result, resultMessage = pcall(function()
		return AvatarCreationService:PromptCreateAvatarAsync(bodyToken, player, humanoidDescription)
	end)

	if not ok then
		logger:warn(`Avatar upload errored for {player.Name}: {result}`)

		return false, `Failed to upload avatar. Reason: {result}`
	end

	return reportResult(player, Enum.PromptCreateAvatarResult, result, resultMessage)
end

return AvatarPublisher

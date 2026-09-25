--[[
	Re-uploads the T-shirt blank's reference cage mesh under this place's own creator, then points
	the blank at the new asset. A copied place still references the original creator's cage, which
	fails to load for anyone else.

	Run manually from Studio (command bar or a temporary Script) — this file lives outside the Rojo
	tree and is never synced into the place. `CreateAssetAsync` must be enabled for the place.

	The `game.CreatorId == 3529469` guard below is Roblox's own resources group: it stops the
	script from re-uploading on the template itself. **Change it to this place's creator id.**
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetUtil = require(ReplicatedStorage.Shared.Modules.Utils.AssetUtil)

if game.CreatorType == Enum.CreatorType.Group and game.CreatorId == 3529469 then
	print("If you've just republished this experience from Roblox Resources, re-open the place to run this script")
	return
end

local tShirtWrapLayer = AssetUtil.resolve("Blanks/TShirtModel/ShirtAccessory/Shirt/TShirt_VNeck_001") :: MeshPart

local referenceCageEditableMesh = AssetService:CreateEditableMeshAsync(tShirtWrapLayer.ReferenceMeshContent)

local _result, id = AssetService:CreateAssetAsync(referenceCageEditableMesh, Enum.AssetType.Mesh, {
	Name = "Reference Cage",
	CreatorId = game.CreatorId,
	CreatorType = if game.CreatorType == Enum.CreatorType.Group
		then Enum.AssetCreatorType.Group
		else Enum.AssetCreatorType.User,
})

-- The upload is not downloadable the instant CreateAssetAsync returns.
task.wait(1)

tShirtWrapLayer.ReferenceMeshContent = Content.fromAssetId(id)

print("Successfully updated reference cage mesh: " .. id)

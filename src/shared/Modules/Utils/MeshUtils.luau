local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreationConfig = require(ReplicatedStorage.Shared.Data.CreationConfig)

--[=[
	@class MeshUtils

	EditableMesh helpers shared by the mesh editing tools — vertex queries, object-space raycasts
	and kitbash geometry merging.
]=]

export type MergeKitbashParams = {
	targetMeshPart: MeshPart,
	targetEditableMesh: EditableMesh,
	targetScaleFactor: Vector3,

	kitbashMeshId: string,
	kitbashTextureId: string,

	positionMarkerCFrame: CFrame,
	scale: number,
	rotation: number,

	baseTextureLayer: EditableImage?,
	atlasSlot: number?,
	hasDrawnToAtlas: boolean,
}

export type EditableMeshRaycastResult = {
	triangleId: number,
	point: Vector3,
	worldPoint: Vector3,
	barycentricCoordinate: Vector3,
	editableMesh: EditableMesh,
	meshPart: MeshPart,
	scaleFactor: Vector3,
}

--[=[
	@within MeshUtils
	@param editableMesh EditableMesh -- the mesh to read
	@return { [number]: Vector3 } -- vertex id to mesh-space position
]=]
local function getVertexPositions(editableMesh: EditableMesh): { [number]: Vector3 }
	local vertexPositions = {}
	for _, vertexId in editableMesh:GetVertices() do
		vertexPositions[vertexId] = editableMesh:GetPosition(vertexId)
	end

	return vertexPositions
end

--[=[
	@within MeshUtils
	@param vertexPositions { [number]: Vector3 } -- the positions to bound
	@return Vector3 -- the minimum corner
	@return Vector3 -- the maximum corner

	The bounds always include the origin — each component starts at zero rather than at the first
	vertex.
]=]
local function getVertexBounds(vertexPositions: { [number]: Vector3 }): (Vector3, Vector3)
	local minX = 0
	local minY = 0
	local minZ = 0
	local maxX = 0
	local maxY = 0
	local maxZ = 0

	for _, position in vertexPositions do
		minX = math.min(minX, position.X)
		minY = math.min(minY, position.Y)
		minZ = math.min(minZ, position.Z)

		maxX = math.max(maxX, position.X)
		maxY = math.max(maxY, position.Y)
		maxZ = math.max(maxZ, position.Z)
	end

	return Vector3.new(minX, minY, minZ), Vector3.new(maxX, maxY, maxZ)
end

--[=[
	@within MeshUtils
	@param editableMesh EditableMesh -- the mesh the triangle belongs to
	@param triangleId number -- the triangle that was hit
	@param barycentricCoordinate Vector3 -- where inside the triangle the hit landed
	@return Vector2 -- the matching UV coordinate

	Turns a mesh hit into a texture coordinate, so a point on an EditableMesh can be mapped onto
	an EditableImage.
]=]
local function getTextureCoordinate(
	editableMesh: EditableMesh,
	triangleId: number,
	barycentricCoordinate: Vector3
): Vector2
	local faceUVs = editableMesh:GetFaceUVs(triangleId)
	local uv1 = editableMesh:GetUV(faceUVs[1]) :: Vector2
	local uv2 = editableMesh:GetUV(faceUVs[2]) :: Vector2
	local uv3 = editableMesh:GetUV(faceUVs[3]) :: Vector2

	local uvCoord = (barycentricCoordinate.X * uv1) + (barycentricCoordinate.Y * uv2) + (barycentricCoordinate.Z * uv3)

	return uvCoord
end

--[=[
	@within MeshUtils
	@param meshPart MeshPart -- the part the mesh is applied to
	@param vertexPositions { [number]: Vector3 } -- the mesh's vertex positions
	@return Vector3 -- mesh units per stud, per axis
]=]
local function getScaleFactor(meshPart: MeshPart, vertexPositions: { [number]: Vector3 }): Vector3
	local min, max = getVertexBounds(vertexPositions)
	local editableMeshSize = max - min
	local scaleFactor = editableMeshSize / meshPart.Size

	return scaleFactor
end

--[=[
	@within MeshUtils
	@param localSpacePos Vector3 -- a position in MeshPart object space
	@param meshPart MeshPart -- the part the mesh is applied to
	@param vertexPositions { [number]: Vector3 } -- the mesh's vertex positions
	@return Vector3 -- the same position in EditableMesh space
]=]
local function localSpaceToEditableMeshSpace(
	localSpacePos: Vector3,
	meshPart: MeshPart,
	vertexPositions: { [number]: Vector3 }
): Vector3
	local meshScaleFactor = getScaleFactor(meshPart, vertexPositions)

	local editableMeshObjectSpacePos = localSpacePos * meshScaleFactor
	return editableMeshObjectSpacePos
end

--[=[
	@within MeshUtils
	@param editableMesh EditableMesh -- the mesh that was hit
	@param meshPart MeshPart -- the part the mesh is applied to
	@param hitPoint Vector3 -- the hit position, in EditableMesh space
	@param hitTriangle number -- the triangle that was hit
	@param meshScaleFactor Vector3 -- mesh units per stud, per axis
	@return CFrame -- the world-space hit, oriented along the surface normal
]=]
local function editableMeshRaycastToCFrame(
	editableMesh: EditableMesh,
	meshPart: MeshPart,
	hitPoint: Vector3,
	hitTriangle: number,
	meshScaleFactor: Vector3
): CFrame
	local vertexNormals = editableMesh:GetFaceNormals(hitTriangle)

	local vertexNormal: Vector3 = (editableMesh:GetNormal(vertexNormals[1]) :: Vector3 + editableMesh:GetNormal(
		vertexNormals[2]
	) :: Vector3 + editableMesh:GetNormal(vertexNormals[3]) :: Vector3).Unit

	local objectSpaceVector = hitPoint / meshScaleFactor
	local offset = meshPart.CFrame:VectorToWorldSpace(objectSpaceVector)
	local worldSpaceNormal = meshPart.CFrame:VectorToWorldSpace(vertexNormal)
	local newCFrame = CFrame.new(meshPart.Position + offset, meshPart.Position + offset + worldSpaceNormal)

	return newCFrame
end

--[=[
	@within MeshUtils
	@param ray Ray -- a world-space ray, usually from the camera
	@param editableMesh EditableMesh -- the mesh to test
	@param meshPart MeshPart -- the part the mesh is applied to
	@param scaleFactor Vector3 -- mesh units per stud, per axis
	@return boolean -- true if the ray hit
	@return EditableMeshRaycastResult? -- details of the hit
]=]
local function castRayFromCamera(
	ray: Ray,
	editableMesh: EditableMesh,
	meshPart: MeshPart,
	scaleFactor: Vector3
): (boolean, EditableMeshRaycastResult?)
	local objectSpaceRayOrigin = meshPart.CFrame:PointToObjectSpace(ray.Origin)
	local objectSpaceRayDirection = meshPart.CFrame:VectorToObjectSpace(ray.Direction).Unit

	objectSpaceRayOrigin = objectSpaceRayOrigin * scaleFactor
	objectSpaceRayDirection = objectSpaceRayDirection * scaleFactor

	local triangleId, hitPoint, barycentricCoordinate =
		editableMesh:RaycastLocal(objectSpaceRayOrigin, objectSpaceRayDirection * 100)
	if not triangleId then
		return false, nil
	end

	local raycastResult: EditableMeshRaycastResult = {
		triangleId = triangleId,
		point = hitPoint,
		worldPoint = meshPart.CFrame:PointToWorldSpace(hitPoint / scaleFactor),
		barycentricCoordinate = barycentricCoordinate,
		editableMesh = editableMesh,
		meshPart = meshPart,
		scaleFactor = scaleFactor,
	}

	return true, raycastResult
end

--[=[
	@within MeshUtils
	@param ray Ray -- a world-space ray, usually from the camera
	@param editableMeshMap { [MeshPart]: EditableMesh } -- the meshes to test
	@param scaleFactorMap { [MeshPart]: Vector3 } -- each mesh's scale factor
	@return EditableMeshRaycastResult? -- the nearest hit, or nil if the ray missed everything
]=]
local function raycastAll(
	ray: Ray,
	editableMeshMap: { [MeshPart]: EditableMesh },
	scaleFactorMap: { [MeshPart]: Vector3 }
): EditableMeshRaycastResult?
	local origin = ray.Origin

	local closestDistance = 100000
	local closestResult = nil

	for meshPart, editableMesh in editableMeshMap do
		local scaleFactor = scaleFactorMap[meshPart]
		local didHit, result = castRayFromCamera(ray, editableMesh, meshPart, scaleFactor)

		if didHit then
			local hitPoint = result.worldPoint
			local distance = (origin - hitPoint).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				result.scaleFactor = scaleFactor
				closestResult = result
			end
		end
	end

	return closestResult
end

--[=[
	@within MeshUtils
	@param params MergeKitbashParams -- the piece to merge and where to put it
	@return { number } -- the face ids added to the target mesh, so the merge can be undone

	Merges a kitbash piece into the target mesh: copies its geometry across, draws its texture (if
	any) into the target's atlas slot, and remaps the copied UVs onto that slot.
]=]
local function mergeKitbashPiece(params: MergeKitbashParams): { number }
	local targetMeshPart = params.targetMeshPart
	local targetEditableMesh = params.targetEditableMesh
	local targetScaleFactor = params.targetScaleFactor

	local kitbashEditableMesh =
		AssetService:CreateEditableMeshAsync(Content.fromUri(params.kitbashMeshId), { FixedSize = false })

	local kitbashVertices = kitbashEditableMesh:GetVertices()
	local kitbashFaces = kitbashEditableMesh:GetFaces()

	local rootBoneId = nil
	local bones = targetEditableMesh:GetBones()
	for _, boneId in bones do
		if targetEditableMesh:GetBoneParent(boneId) == 0 then
			rootBoneId = boneId
			break
		end
	end

	local hasKitbashTexture = params.kitbashTextureId ~= ""
	if hasKitbashTexture and not params.hasDrawnToAtlas and params.atlasSlot and params.baseTextureLayer then
		local atlasSize = params.baseTextureLayer.Size
		local slotInfo = CreationConfig.atlasSlots[params.atlasSlot]

		local kitbashTexture = AssetService:CreateEditableImageAsync(Content.fromUri(params.kitbashTextureId))

		local slotSize = atlasSize.X / CreationConfig.atlasGridSize
		local scaleX = slotSize / kitbashTexture.Size.X
		local scaleY = slotSize / kitbashTexture.Size.Y

		params.baseTextureLayer:DrawImageTransformed(
			Vector2.new(atlasSize.X * slotInfo.uCenter, atlasSize.Y * slotInfo.vCenter),
			Vector2.new(scaleX, scaleY),
			0,
			kitbashTexture
		)

		kitbashTexture:Destroy()
	end

	local rotationDegrees = params.rotation or 0
	local rotationCFrame = CFrame.Angles(0, 0, math.rad(rotationDegrees))
	local kitbashToWorld = params.positionMarkerCFrame * rotationCFrame
	local vertexIdMap = {}
	local uvIdMap = {}
	local addedFaceIds = {}

	for _, oldVertexId in kitbashVertices do
		local localPos = kitbashEditableMesh:GetPosition(oldVertexId)
		local scaledPos = localPos * params.scale
		local worldPos = kitbashToWorld:PointToWorldSpace(scaledPos)
		local targetLocalPos = targetMeshPart.CFrame:PointToObjectSpace(worldPos)
		local normalizedPos = targetLocalPos * targetScaleFactor

		local newVertexId = targetEditableMesh:AddVertex(normalizedPos)
		vertexIdMap[oldVertexId] = newVertexId

		if rootBoneId then
			targetEditableMesh:SetVertexBones(newVertexId, { rootBoneId })
			targetEditableMesh:SetVertexBoneWeights(newVertexId, { 1 })
		end
	end

	local remapsUVs = params.atlasSlot ~= nil
	if params.atlasSlot then
		local kitbashUVs = kitbashEditableMesh:GetUVs()
		local slotInfo = CreationConfig.atlasSlots[params.atlasSlot]
		local slotScale = 1.0 / CreationConfig.atlasGridSize

		for _, oldUVId in kitbashUVs do
			local uvCoord = kitbashEditableMesh:GetUV(oldUVId)
			local remappedUV =
				Vector2.new(slotInfo.uOffset + (uvCoord.X * slotScale), slotInfo.vOffset + (uvCoord.Y * slotScale))

			local newUVId = targetEditableMesh:AddUV(remappedUV)
			uvIdMap[oldUVId] = newUVId
		end
	end

	for _, oldFaceId in kitbashFaces do
		local oldVertices = kitbashEditableMesh:GetFaceVertices(oldFaceId)
		local oldUVs = kitbashEditableMesh:GetFaceUVs(oldFaceId)

		local newVertices = {}
		local newUVs = {}

		for i, oldVertexId in oldVertices do
			newVertices[i] = vertexIdMap[oldVertexId]
		end

		if remapsUVs then
			for i, oldUVId in oldUVs do
				newUVs[i] = uvIdMap[oldUVId]
			end
		end

		if #newVertices == 3 then
			local newFaceId = targetEditableMesh:AddTriangle(newVertices[1], newVertices[2], newVertices[3])

			if remapsUVs and #newUVs == 3 then
				targetEditableMesh:SetFaceUVs(newFaceId, newUVs)
			end

			table.insert(addedFaceIds, newFaceId)
		end
	end

	targetEditableMesh:RemoveUnused()
	kitbashEditableMesh:Destroy()

	return addedFaceIds
end

return {
	getVertexPositions = getVertexPositions,
	getVertexBounds = getVertexBounds,
	getTextureCoordinate = getTextureCoordinate,
	getScaleFactor = getScaleFactor,
	localSpaceToEditableMeshSpace = localSpaceToEditableMeshSpace,
	editableMeshRaycastToCFrame = editableMeshRaycastToCFrame,
	castRayFromCamera = castRayFromCamera,
	raycastAll = raycastAll,
	mergeKitbashPiece = mergeKitbashPiece,
}

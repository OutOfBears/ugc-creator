export type AtlasSlot = {
	uOffset: number,
	vOffset: number,
	uCenter: number,
	vCenter: number,
}

export type CreationConfig = {
	creationTypes: { body: string, accessory: string },
	editModes: { none: number, mesh: number, paint: number, choosingPart: number },
	paintStates: { painting: number, erasing: number },
	widgetTypes: {
		sphere: string,
		cylinder: string,
		muscle: string,
		growShrink: string,
		axisStretch: string,
	},
	controlTypes: { line: string, plane: string },
	layerNames: { fabricFill: string, stickerPrefix: string },
	paintBlendModes: { normal: string, add: string, subtract: string, multiply: string },
	paintBlendModeOrder: { string },
	defaultPaintLayerId: string,

	maxPaintLayers: number,
	maxPaintLayerIdLength: number,
	maxStickerLayers: number,
	minBrushSize: number,
	maxBrushSize: number,
	scaleDragSensitivity: number,
	minStickerPadding: number,
	maxStickerPadding: number,
	defaultTiledStickerScale: number,
	accessoryStickerScale: number,

	textureResolutionSteps: { Vector2 },

	defaultKitbashMinScale: number,
	defaultKitbashMaxScale: number,
	atlasGridSize: number,
	atlasMaxKitbashPieces: number,
	atlasSlots: { AtlasSlot },

	pbrMapCellSize: Vector2,
	pbrDefaultMetalColor: Color3,
	pbrDefaultRoughColor: Color3,
	pbrDefaultNormalColor: Color3,
	pbrReflectiveMetalColor: Color3,
	pbrReflectiveRoughColor: Color3,

	adjustableRigidAccessories: { [Enum.AvatarAssetType]: boolean },

	camera: {
		fieldOfView: number,
		minDistance: number,
		maxDistance: number,
		minAccessoryDistance: number,
		scrollZoomStep: number,
		touchZoomStep: number,
		accessoryDistanceScale: number,
		accessoryZoom: number,
		mobileAccessoryPanXOffsetScale: number,
		tweenInfo: TweenInfo,
		previewFieldOfView: number,
		previewOffset: Vector3,
		editFieldOfView: number,
		playerFieldOfView: number,
	},

	display: {
		degreesPerPixel: number,
		minOffsetX: number,
		maxOffsetX: number,
		minOffsetY: number,
		maxOffsetY: number,
		minOffsetZ: number,
		maxOffsetZ: number,
	},

	input: {
		thumbstickDeadzone: number,
		maxZoomSpeed: number,
		minAxisThreshold: number,
		maxStickAngularSpeed: number,
		virtualCursorUpdatesPerSecond: number,
	},

	widgets: {
		color: Color3,
		draggingColor: Color3,
	},

	uvCanvas: {
		minZoom: number,
		maxZoom: number,
		zoomStepFactor: number,
		pinchZoomPixelsPerStep: number,
		wireframeColor: Color3,
		wireframeOverlayTransparency: number,
		wireframeThicknessScale: number,
		heightScale: number,
		panelGap: number,
		modelScreenXScale: number,
		stickerHitRadius: number,
		minWindowSize: number,
		checkerColorA: Color3,
		checkerColorB: Color3,
		checkerCellSize: number,
		wireframeFacesPerYield: number,
	},

	reopenDebounceSeconds: number,

	paintEdgeBleedDelay: number,

	projectionEnabled: boolean,
	visualizeServerEdits: boolean,
}

local ATLAS_GRID_SIZE = 2

-- Slot (0,0) is reserved for the base texture, so kitbash pieces start at the second cell.
local function generateAtlasSlots(gridSize: number): { AtlasSlot }
	local slots = {}
	local slotSize = 1 / gridSize

	for row = 0, gridSize - 1 do
		for col = 0, gridSize - 1 do
			if row == 0 and col == 0 then
				continue
			end

			table.insert(slots, {
				uOffset = col * slotSize,
				vOffset = row * slotSize,
				uCenter = (col + 0.5) * slotSize,
				vCenter = (row + 0.5) * slotSize,
			})
		end
	end

	return slots
end

--[=[
	@class CreationConfig

	Tuning for the item creation editor — tool limits, texture resolution ladder, kitbash atlas
	layout, and the packed PBR colors written into freshly created editable images.

	`visualizeServerEdits` parents the server's authoritative copy of the model into `Workspace`
	instead of `ServerStorage`, which is a debugging aid only.
]=]
local config: CreationConfig = {
	creationTypes = {
		body = "Body",
		accessory = "Accessory",
	},
	editModes = {
		none = 0,
		mesh = 1,
		paint = 2,
		choosingPart = 3,
	},
	paintStates = {
		painting = 1,
		erasing = 2,
	},
	widgetTypes = {
		sphere = "Sphere",
		cylinder = "Cylinder",
		muscle = "Muscle",
		growShrink = "GrowShrink",
		axisStretch = "AxisStretch",
	},
	controlTypes = {
		line = "Line",
		plane = "Plane",
	},
	layerNames = {
		fabricFill = "FabricFillLayer",
		stickerPrefix = "StickerLayer",
	},
	paintBlendModes = {
		normal = "Normal",
		add = "Add",
		subtract = "Subtract",
		multiply = "Multiply",
	},
	paintBlendModeOrder = { "Normal", "Add", "Subtract", "Multiply" },
	defaultPaintLayerId = "DefaultPaintLayer",

	maxPaintLayers = 8,
	maxPaintLayerIdLength = 64,
	maxStickerLayers = 3,
	minBrushSize = 1.5,
	maxBrushSize = 50,
	scaleDragSensitivity = 0.02,
	minStickerPadding = 0,
	maxStickerPadding = 100,
	defaultTiledStickerScale = 0.5,
	accessoryStickerScale = 0.5,

	textureResolutionSteps = {
		Vector2.new(1024, 1024),
		Vector2.new(512, 512),
		Vector2.new(256, 256),
		Vector2.new(128, 128),
	},

	defaultKitbashMinScale = 0.5,
	defaultKitbashMaxScale = 2,
	atlasGridSize = ATLAS_GRID_SIZE,
	atlasMaxKitbashPieces = (ATLAS_GRID_SIZE * ATLAS_GRID_SIZE) - 1,
	atlasSlots = generateAtlasSlots(ATLAS_GRID_SIZE),

	pbrMapCellSize = Vector2.new(256, 256),
	pbrDefaultMetalColor = Color3.fromRGB(0, 0, 0),
	pbrDefaultRoughColor = Color3.fromRGB(255, 255, 255),
	pbrDefaultNormalColor = Color3.fromRGB(127, 127, 255),
	pbrReflectiveMetalColor = Color3.fromRGB(255, 255, 255),
	pbrReflectiveRoughColor = Color3.fromRGB(0, 0, 0),

	adjustableRigidAccessories = {
		[Enum.AvatarAssetType.Hat] = true,
		[Enum.AvatarAssetType.FaceAccessory] = true,
		[Enum.AvatarAssetType.BackAccessory] = true,
	},

	camera = {
		fieldOfView = 30,
		minDistance = 1.5,
		maxDistance = 12,
		minAccessoryDistance = 4,
		scrollZoomStep = -1,
		touchZoomStep = -0.05,
		accessoryDistanceScale = 3,
		accessoryZoom = 0.85,
		mobileAccessoryPanXOffsetScale = 2,
		tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut, 0, false, 0),
		previewFieldOfView = 35,
		previewOffset = Vector3.new(0, 0, -12),
		editFieldOfView = 35,
		playerFieldOfView = 70,
	},

	display = {
		degreesPerPixel = 0.5,
		minOffsetX = -2,
		maxOffsetX = 2,
		minOffsetY = -1,
		maxOffsetY = 1,
		minOffsetZ = -3,
		maxOffsetZ = 2,
	},

	input = {
		thumbstickDeadzone = 0.2,
		maxZoomSpeed = 10,
		minAxisThreshold = 0.5,
		maxStickAngularSpeed = math.rad(140),
		virtualCursorUpdatesPerSecond = 10,
	},

	widgets = {
		color = Color3.fromHex("262626"),
		draggingColor = Color3.fromHex("3C64FA"),
	},

	uvCanvas = {
		minZoom = 1,
		maxZoom = 16,
		zoomStepFactor = 1.2,
		pinchZoomPixelsPerStep = 40,
		wireframeColor = Color3.fromHex("3C64FA"),
		wireframeOverlayTransparency = 0.5,
		wireframeThicknessScale = 0.004,
		heightScale = 0.8,
		panelGap = 12,
		modelScreenXScale = 0.15,
		stickerHitRadius = 40,
		minWindowSize = 240,
		checkerColorA = Color3.fromHex("3A3A3F"),
		checkerColorB = Color3.fromHex("2B2B30"),
		checkerCellSize = 12,
		wireframeFacesPerYield = 2000,
	},

	reopenDebounceSeconds = 3,

	paintEdgeBleedDelay = 0.25,

	projectionEnabled = true,
	visualizeServerEdits = false,
}

table.freeze(config)

return config

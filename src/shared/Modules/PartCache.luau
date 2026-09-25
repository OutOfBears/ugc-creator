--!native
local RunService = game:GetService("RunService")

local FAR_AWAY_CFRAME = CFrame.new(2 ^ 24, 2 ^ 24, 2 ^ 24)
local DEFAULT_EXPAND_AMOUNT = 50
local DEFAULT_CACHE_SIZE = 10
local BATCH_PREALLOC = 10_000
local IS_STUDIO = RunService:IsStudio()

local movingParts = table.create(BATCH_PREALLOC) :: { BasePart }
local movingCFrames = table.create(BATCH_PREALLOC) :: { CFrame }
local scheduledUpdate = false
local updateMovementThread: thread? = nil

type Template = BasePart | Model

export type PartCache = {
	-- vars
	cacheHolder: Folder,
	template: Template,
	isTemplateModel: boolean,
	expandAmount: number,
	preallocatedAmount: number,
	freeObjects: { BasePart },
	objects: { [BasePart]: boolean },

	-- methods
	getPart: (self: PartCache, partCFrame: CFrame?) -> BasePart,
	returnPart: (self: PartCache, part: BasePart) -> (),
	update: (self: PartCache) -> (),
	expandCache: (self: PartCache, amount: number) -> (),
	setExpandAmount: (self: PartCache, amount: number) -> (),
	isInUse: (self: PartCache, part: BasePart) -> boolean,
	destroy: (self: PartCache) -> (),
}

local function createCacheHolder(): Folder
	local cacheHolder = Instance.new("Folder")
	cacheHolder.Name = "ObjectCache"

	return cacheHolder
end

local function updateMovement()
	while true do
		workspace:BulkMoveTo(movingParts, movingCFrames, Enum.BulkMoveMode.FireCFrameChanged)

		table.clear(movingParts)
		table.clear(movingCFrames)

		scheduledUpdate = false
		coroutine.yield()
	end
end

local PartCache = {}

--[=[
	@class PartCache

	Reuses a pool of cloned parts (or models) instead of creating and destroying
	them, batching every move through a single deferred `BulkMoveTo`. Free parts
	sit parked at [FAR_AWAY_CFRAME] until claimed with [PartCache:getPart].
]=]

--[=[
	@within PartCache
	@param template BasePart | Model -- part, or model with a PrimaryPart, to clone
	@param cacheSize number? -- parts to preallocate up front (default 10)
	@param cachesContainer Instance? -- parent for the cache folder (default workspace)
	@return PartCache
]=]
function PartCache.new(template: Template, cacheSize: number?, cachesContainer: Instance?): PartCache
	local templateType = typeof(template)
	assert(templateType == "Instance", `Invalid argument #1 to 'PartCache.new' (BasePart expected, got {templateType})`)

	assert(
		template:IsA("BasePart") or template:IsA("Model"),
		`Invalid argument #1 to 'PartCache.new' (BasePart or Model expected, got {template.ClassName})`
	)
	assert(template.Archivable, `PartCache: Cannot use template object provided, as it has Archivable set to false.`)
	if template:IsA("Model") then
		assert(
			template.PrimaryPart ~= nil,
			`Invalid Template provided to 'PartCache.new': Model has no PrimaryPart set!`
		)
	end

	local cacheSizeType = typeof(cacheSize)
	assert(
		cacheSize == nil or cacheSizeType == "number",
		`Invalid argument #2 to 'PartCache.new' (number expected, got {cacheSizeType})`
	)
	assert(
		cacheSize == nil or cacheSize >= 0,
		`Invalid argument #2 to 'PartCache.new' (positive number expected, got {cacheSize})`
	)

	local containerType = typeof(cachesContainer)
	assert(
		cachesContainer == nil or containerType == "Instance",
		`Invalid argument #3 to 'PartCache.new' (Instance expected, got {containerType})`
	)

	if not updateMovementThread or coroutine.status(updateMovementThread) == "dead" then
		updateMovementThread = coroutine.create(updateMovement)
	end

	local preallocAmount = cacheSize or DEFAULT_CACHE_SIZE
	local cacheHolder = createCacheHolder()

	local objects: { [BasePart]: boolean } = {}
	local freeObjects = table.create(preallocAmount) :: { BasePart }

	local isTemplateModel = template:IsA("Model")
	for index = 1, preallocAmount do
		local clone = template:Clone()
		local root: BasePart = if isTemplateModel then (clone :: Model).PrimaryPart :: BasePart else clone :: BasePart

		freeObjects[index] = root

		root.CFrame = FAR_AWAY_CFRAME;
		(clone :: Instance).Parent = cacheHolder
	end

	cacheHolder.Parent = cachesContainer or workspace.Terrain

	local object = {} :: PartCache
	object.cacheHolder = cacheHolder
	object.template = template
	object.isTemplateModel = isTemplateModel
	object.expandAmount = DEFAULT_EXPAND_AMOUNT
	object.preallocatedAmount = preallocAmount
	object.freeObjects = freeObjects
	object.objects = objects

	local function getNew(amount: number, shouldWarn: boolean): BasePart
		if shouldWarn and IS_STUDIO then
			warn(`PartCache: Cache retrieval exceeded preallocated amount! expanding by {amount}...`)
		end

		local initialLength = #object.freeObjects

		local targetParts = table.create(amount) :: { BasePart }
		local targetCFrames = table.create(amount) :: { CFrame }
		local addedClones = table.create(amount)

		for index = initialLength + 1, initialLength + amount do
			local clone = object.template:Clone()
			local root: BasePart = if object.isTemplateModel
				then (clone :: Model).PrimaryPart :: BasePart
				else clone :: BasePart

			object.freeObjects[index] = root

			local offsetIndex = index - initialLength
			targetParts[offsetIndex] = root
			targetCFrames[offsetIndex] = FAR_AWAY_CFRAME
			addedClones[offsetIndex] = clone
		end

		workspace:BulkMoveTo(targetParts, targetCFrames, Enum.BulkMoveMode.FireCFrameChanged)

		for _, clone in addedClones do
			(clone :: Instance).Parent = object.cacheHolder
		end

		return table.remove(object.freeObjects) :: BasePart
	end

	--[=[
		@within PartCache
		@param partCFrame CFrame? -- where to move the claimed part; nil leaves it parked
		@return BasePart -- a part removed from the free pool, expanding the cache if empty
	]=]
	function object:getPart(partCFrame: CFrame?): BasePart
		local part: BasePart = table.remove(self.freeObjects) or getNew(self.expandAmount, true)

		self.objects[part] = nil
		if partCFrame then
			table.insert(movingParts, part)
			table.insert(movingCFrames, partCFrame)

			if not scheduledUpdate then
				scheduledUpdate = true
				task.defer(updateMovementThread :: thread)
			end
		end

		return part
	end

	--[=[
		@within PartCache
		@param part BasePart -- a part previously handed out by [PartCache:getPart]

		Parks the part back at [FAR_AWAY_CFRAME] and returns it to the free pool.
	]=]
	function object:returnPart(part: BasePart)
		if self.objects[part] then
			return
		end

		self.objects[part] = true

		table.insert(self.freeObjects, part)
		table.insert(movingParts, part)
		table.insert(movingCFrames, FAR_AWAY_CFRAME)

		if not scheduledUpdate then
			scheduledUpdate = true
			task.defer(updateMovementThread :: thread)
		end
	end

	--[=[
		@within PartCache

		Flushes the pending batched moves immediately instead of waiting for the
		deferred update.
	]=]
	function object:update()
		task.spawn(updateMovementThread :: thread)
	end

	--[=[
		@within PartCache
		@param amount number -- extra parts to preallocate into the free pool
	]=]
	function object:expandCache(amount: number)
		assert(
			typeof(amount) ~= "number" or amount >= 0,
			`Invalid argument #1 to 'PartCache:expandCache' (positive number expected, got {typeof(amount)})`
		)
		getNew(amount, false)
	end

	--[=[
		@within PartCache
		@param amount number -- parts to add each time the pool runs dry
	]=]
	function object:setExpandAmount(amount: number)
		assert(
			typeof(amount) ~= "number" or amount > 0,
			`Invalid argument #1 to 'PartCache:setExpandAmount' (positive number expected, got {typeof(amount)})`
		)
		self.expandAmount = amount
	end

	--[=[
		@within PartCache
		@param part BasePart
		@return boolean -- true if the part is currently claimed (not in the free pool)
	]=]
	function object:isInUse(part: BasePart): boolean
		return self.objects[part] == nil
	end

	function object:destroy()
		self.cacheHolder:Destroy()
	end

	return object
end

return PartCache

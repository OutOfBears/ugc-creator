local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Shared.Modules.Promise)
local NumberUtils = require(ReplicatedStorage.Shared.Modules.Utils.NumberUtils)
local PooledConnection = require("./PooledConnection")
local Types = require("../Types")
local Logger = require("./Logger")

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = if IS_SERVER then "Services" else "Controllers"

local Loader = {
	_events = {},
}

local logger = Logger.new()

export type LoaderModule = Types.LoaderModule
export type LoaderEvent = Types.LoaderEvent

function Loader.connectToEvent(event: LoaderEvent, callback: (...any) -> (), priority: number?)
	local events = Loader._events[event]
	if not events then
		events = {}
		Loader._events[event] = events

		PooledConnection(RunService[event]):Connect(function(...)
			for _, eventData in events do
				eventData.callback(...)
			end
		end)
	end

	table.insert(events, { callback = callback, priority = priority or 0 })
	table.sort(events, function(a, b)
		return a.priority > b.priority
	end)
end

function Loader.initalize(root: Instance, filter: ((module: ModuleScript) -> boolean)?)
	local modulesFolder = root:WaitForChild(FOLDER_NAME)
	local modules = {} :: { LoaderModule }

	for _, module in modulesFolder:GetChildren() do
		if not module:IsA("ModuleScript") then
			continue
		end

		if filter and not filter(module) then
			continue
		end

		local data = require(module :: any) :: any
		data.name = module.Name
		data.priority = data.priority or 0
		data.loadTime = tick()
		table.insert(modules, data)
	end

	table.sort(modules, function(a, b)
		return a.priority < b.priority
	end)

	for _, module in modules do
		if module.onInit then
			module.onInit()
			logger:debug(
				`Initialized {module.name} (took {NumberUtils.abbreviateTime(tick() - (module.loadTime or 0))})`
			)
		end
	end

	for _, module in modules do
		if not module.onRun then
			continue
		end

		local onRun = Promise.promisify(module.onRun)
		onRun():catch(function(err)
			warn("Error running onRun for module:", err)
		end)
	end

	for _, module in modules do
		if module.onStepped then
			Loader.connectToEvent("Stepped", module.onStepped, module.priority)
		end

		if module.onRenderStepped then
			Loader.connectToEvent("RenderStepped", module.onRenderStepped, module.priority)
		end

		if module.onHeartbeat then
			Loader.connectToEvent("Heartbeat", module.onHeartbeat, module.priority)
		end

		if module.onPreSimulation then
			Loader.connectToEvent("PreSimulation", module.onPreSimulation, module.priority)
		end

		if module.onPostSimulation then
			Loader.connectToEvent("PostSimulation", module.onPostSimulation, module.priority)
		end
	end

	if IS_SERVER then
		logger:debug(`Server initialized with {#modules} modules.`)
	else
		logger:debug(`Client initialized with {#modules} modules.`)
	end
end

return Loader

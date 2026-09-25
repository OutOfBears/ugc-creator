local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")
local Logger = {}

local PrettyPrint = require(script.PrettyPrint)

export type Context = { [string]: any }
export type LogLevel = "trace" | "debug" | "info" | "warn" | "error" | string
export type LogCallback = (data: LogRecord) -> ()
export type LogRecord = { level: LogLevel, message: string, context: Context }

local IS_STUDIO = RunService:IsStudio()
local LOG_LEGACY = false

local LOG_LEVEL_NAMES = {
	"TRACE",
	"DEBUG",
	"INFO",
	"WARN",
	"ERROR",
}

local LOG_LEVELS = {
	trace = 1,
	debug = 2,
	info = 3,
	warn = 4,
	error = 5,
} :: { [LogLevel]: number }

local LOG_EMOJIS = {
	trace = "🔍",
	debug = "🐞",
	info = "ℹ️",
	warn = "⚠️",
	error = "⛔",
}

Logger.LogLevels = LOG_LEVELS

local function logToPrint(module: string)
	return function(data: LogRecord)
		local level = LOG_LEVEL_NAMES[LOG_LEVELS[data.level]] or "INFO"
		local emoji = LOG_EMOJIS[data.level] or ""
		local contextPrint = ""

		if next(data.context) then
			contextPrint = PrettyPrint(data.context)
		end

		if data.level == "warn" or data.level == "error" then
			warn(`{emoji} [{level}] [{module}] {data.message}{contextPrint}`)
		else
			print(`{emoji} [{level}] [{module}] {data.message}{contextPrint}`)
		end
	end
end

local function logToLogService(module: string)
	local LOG_TYPE_TO_MESSAGE_TYPE = {
		trace = Enum.MessageType.MessageInfo,
		debug = Enum.MessageType.MessageInfo,
		info = Enum.MessageType.MessageOutput,
		warn = Enum.MessageType.MessageWarning,
		error = Enum.MessageType.MessageError,
	}

	return function(data: LogRecord)
		local level = LOG_LEVEL_NAMES[LOG_LEVELS[data.level]] or "INFO"
		local emoji = LOG_EMOJIS[data.level] or ""

		LogService:Log(
			LOG_TYPE_TO_MESSAGE_TYPE[data.level],
			`{emoji} [{level}] [{module}] {data.message}`,
			data.context
		)
	end
end

function Logger.new(baseContext: Context?)
	local log = {}
	local callbacks = {}

	log.LogLevel = (if IS_STUDIO then "debug" else "info") :: LogLevel
	log.Context = (baseContext or {}) :: Context
	log.Module = `{debug.info(2, "s"):match("([^%.]+)$")}.luau`

	function log:getLogLevel()
		return LOG_LEVELS[self.LogLevel] or 1
	end

	function log:addLogCallback(callback: LogCallback)
		table.insert(callbacks, callback)
		return function()
			local index = table.find(callbacks, callback)
			if index then
				table.remove(callbacks, index)
			end
		end
	end

	function log:with(context: Context)
		for key, value in context do
			self.Context[key] = value
		end

		return self.Context
	end

	function log:log(level: LogLevel, message: string, context: Context?)
		local logLevel = LOG_LEVELS[level] or 1
		if logLevel < self:getLogLevel() then
			return
		end

		local finalContext = table.clone(self.Context)

		if context then
			for key, value in context do
				finalContext[key] = value
			end
		end

		for _, callback in callbacks do
			task.spawn(callback, { level = level, message = message, context = finalContext })
		end
	end

	function log:trace(message: string, context: Context?)
		self:log("trace", message, context)
	end

	function log:debug(message: string, context: Context?)
		self:log("debug", message, context)
	end

	function log:info(message: string, context: Context?)
		self:log("info", message, context)
	end

	function log:warn(message: string, context: Context?)
		self:log("warn", message, context)
	end

	function log:error(message: string, context: Context?)
		self:log("error", message, context)
	end

	if LOG_LEGACY then
		log:addLogCallback(logToPrint(log.Module))
	else
		log:addLogCallback(logToLogService(log.Module))
	end

	return log
end

return Logger

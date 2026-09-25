--[=[
	@class NetworkClient

	Client-side networking interface. Waits for `RemoteEvent`, `UnreliableRemoteEvent`,
	and `RemoteFunction` instances created by the server inside `ReplicatedStorage.NetworkEvents`.
	Remote instances are cached after the first lookup so `WaitForChild` is only called once
	per event name.

	Obtain via the shared init module:
	```lua
	local Network = require(script.Parent.Network).client()
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "Network"
local FOLDER_TIMEOUT = 10

local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, FOLDER_TIMEOUT)
assert(
	folder,
	`[Network] '{FOLDER_NAME}' folder not found in ReplicatedStorage after {FOLDER_TIMEOUT}s — ensure the server module is required`
)

local cache: { [string]: Instance } = {}

local function waitFor(prefix: string, name: string): Instance
	local key = prefix .. ":" .. name
	if cache[key] then
		return cache[key]
	end

	local instance = folder:WaitForChild(key)
	cache[key] = instance

	return instance
end

--[=[
	@within NetworkClient
	@param eventName string -- Name of the `RE:eventName` RemoteEvent to listen on.
	@param callback (...any) -> () -- Handler invoked when the server fires the event.
	@return () -> () -- Call to disconnect this listener.

	Connects a handler to a reliable RemoteEvent fired from the server.

	```lua
	local disconnect = Network.on("Notification", function(message)
		print(message)
	end)

	-- Later:
	disconnect()
	```
]=]
local function on(eventName: string, callback: (...any) -> ()): () -> ()
	local re = waitFor("RE", eventName) :: RemoteEvent
	local connection = re.OnClientEvent:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

--[=[
	@within NetworkClient
	@param eventName string -- Name of the `URE:eventName` UnreliableRemoteEvent to listen on.
	@param callback (...any) -> () -- Handler invoked when the server fires the event.
	@return () -> () -- Call to disconnect this listener.

	Connects a handler to an unreliable RemoteEvent fired from the server. Prefer this for
	high-frequency data (e.g. world-state updates) where occasional packet loss is acceptable.

	```lua
	local disconnect = Network.onUnreliable("EnemyPosition", function(id, position)
		-- update enemy position
	end)
	```
]=]
local function onUnreliable(eventName: string, callback: (...any) -> ()): () -> ()
	local ure = waitFor("URE", eventName) :: UnreliableRemoteEvent
	local connection = ure.OnClientEvent:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

--[=[
	@within NetworkClient
	@param eventName string -- Name of the `RE:eventName` RemoteEvent.
	@param ... any -- Values to send.

	Fires a reliable RemoteEvent to the server.

	```lua
	Network.fire("PlayerAction", "Jump")
	```
]=]
local function fire(eventName: string, ...: any)
	local re = waitFor("RE", eventName) :: RemoteEvent
	re:FireServer(...)
end

--[=[
	@within NetworkClient
	@param eventName string -- Name of the `URE:eventName` UnreliableRemoteEvent.
	@param ... any -- Values to send.

	Fires an unreliable RemoteEvent to the server. Packets may be dropped or arrive out of
	order — suitable for high-frequency updates where staleness is acceptable.

	```lua
	Network.fireUnreliable("PlayerMoved", character.PrimaryPart.Position)
	```
]=]
local function fireUnreliable(eventName: string, ...: any)
	local ure = waitFor("URE", eventName) :: UnreliableRemoteEvent
	ure:FireServer(...)
end

--[=[
	@within NetworkClient
	@yields
	@param eventName string -- Name of the `RF:eventName` RemoteFunction.
	@param ... any -- Arguments forwarded to the server handler.
	@return ...any -- Values returned by the server handler.

	Invokes a RemoteFunction on the server and yields until the server responds.

	```lua
	local coins = Network.invokeServer("GetCoins")
	```
]=]
local function invokeServer(eventName: string, ...: any): ...any
	local rf = waitFor("RF", eventName) :: RemoteFunction
	return rf:InvokeServer(...)
end

return {
	on = on,
	onUnreliable = onUnreliable,
	fire = fire,
	fireUnreliable = fireUnreliable,
	invokeServer = invokeServer,
}

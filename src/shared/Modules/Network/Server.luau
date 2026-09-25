--[=[
	@class NetworkServer

	Server-side networking interface. Lazily creates `RemoteEvent`, `UnreliableRemoteEvent`,
	and `RemoteFunction` instances inside `ReplicatedStorage.NetworkEvents` using the naming
	convention `RE:Name`, `URE:Name`, and `RF:Name`.

	Obtain via the shared init module:
	```lua
	local Network = require(script.Parent.Network).server()
	```
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "Network"

local folder = Instance.new("Folder")
folder.Name = FOLDER_NAME
folder.Parent = ReplicatedStorage

local cache: { [string]: Instance } = {}

local function getOrCreate(prefix: string, name: string): Instance
	local key = prefix .. ":" .. name
	if cache[key] then
		return cache[key]
	end

	local instance: Instance
	if prefix == "RE" then
		instance = Instance.new("RemoteEvent")
	elseif prefix == "URE" then
		instance = Instance.new("UnreliableRemoteEvent")
	elseif prefix == "RF" then
		instance = Instance.new("RemoteFunction")
	else
		error(`[Network] Unknown prefix '{prefix}' for event '{name}'`, 2)
	end

	instance.Name = key
	instance.Parent = folder
	cache[key] = instance

	return instance
end

--[=[
	@within NetworkServer
	@param eventName string -- Name of the `RE:eventName` RemoteEvent to listen on.
	@param callback (player: Player, ...any) -> () -- Handler invoked when a client fires the event.
	@return () -> () -- Call to disconnect this listener.

	Connects a handler to a reliable RemoteEvent fired from any client.

	```lua
	local disconnect = Network.on("PlayerAction", function(player, action)
		print(player.Name, action)
	end)

	-- Later:
	disconnect()
	```
]=]
local function on(eventName: string, callback: (player: Player, ...any) -> ()): () -> ()
	local re = getOrCreate("RE", eventName) :: RemoteEvent
	local connection = re.OnServerEvent:Connect(callback)

	return function()
		connection:Disconnect()
	end
end

--[=[
	@within NetworkServer
	@param eventName string -- Name of the `URE:eventName` UnreliableRemoteEvent to listen on.
	@param callback (player: Player, ...any) -> () -- Handler invoked when a client fires the event.
	@return () -> () -- Call to disconnect this listener.

	Connects a handler to an unreliable RemoteEvent fired from any client. Prefer this for
	high-frequency data (e.g. positional updates) where occasional packet loss is acceptable.

	```lua
	local disconnect = Network.onUnreliable("PlayerMoved", function(player, position)
		-- update position
	end)
	```
]=]
local function onUnreliable(eventName: string, callback: (player: Player, ...any) -> ()): () -> ()
	local ure = getOrCreate("URE", eventName) :: UnreliableRemoteEvent
	local connection = ure.OnServerEvent:Connect(callback)

	return function()
		connection:Disconnect()
	end
end

--[=[
	@within NetworkServer
	@param eventName string -- Name of the `RF:eventName` RemoteFunction to handle.
	@param callback (player: Player, ...any) -> ...any -- Handler whose return values are sent back to the invoking client.
	@return () -> () -- Call to unregister this handler (sets `OnServerInvoke` to `nil`).

	Registers an invoke handler for a RemoteFunction called from a client. Only one handler
	can be active per event name at a time; registering a second replaces the first.

	```lua
	local disconnect = Network.onInvoke("GetCoins", function(player)
		return Coins:Get(player)
	end)
	```
]=]
local function onInvoke(eventName: string, callback: (player: Player, ...any) -> ...any): () -> ()
	local rf = getOrCreate("RF", eventName) :: RemoteFunction
	rf.OnServerInvoke = callback

	return function()
		if rf.OnServerInvoke == callback then
			rf.OnServerInvoke = nil :: any
		end
	end
end

--[=[
	@within NetworkServer
	@param player Player -- The recipient.
	@param eventName string -- Name of the `RE:eventName` RemoteEvent.
	@param ... any -- Values to send.

	Fires a reliable RemoteEvent to a single client.

	```lua
	Network.fireClient(player, "Notification", "You earned a badge!")
	```
]=]
local function fireClient(player: Player, eventName: string, ...: any)
	local re = getOrCreate("RE", eventName) :: RemoteEvent
	re:FireClient(player, ...)
end

--[=[
	@within NetworkServer
	@param eventName string -- Name of the `RE:eventName` RemoteEvent.
	@param ... any -- Values to send.

	Fires a reliable RemoteEvent to every connected client.

	```lua
	Network.fireAllClients("RoundStarted", roundData)
	```
]=]
local function fireAllClients(eventName: string, ...: any)
	local re = getOrCreate("RE", eventName) :: RemoteEvent
	re:FireAllClients(...)
end

--[=[
	@within NetworkServer
	@param eventName string -- Name of the `RE:eventName` RemoteEvent.
	@param ... any -- Values to send.

	Alias for [NetworkServer.fireAllClients].
]=]
local function broadcast(eventName: string, ...: any)
	fireAllClients(eventName, ...)
end

--[=[
	@within NetworkServer
	@param player Player -- The recipient.
	@param eventName string -- Name of the `URE:eventName` UnreliableRemoteEvent.
	@param ... any -- Values to send.

	Fires an unreliable RemoteEvent to a single client. Packets may be dropped or arrive
	out of order — suitable for high-frequency updates where staleness is acceptable.

	```lua
	Network.fireClientUnreliable(player, "EnemyPosition", position)
	```
]=]
local function fireClientUnreliable(player: Player, eventName: string, ...: any)
	local ure = getOrCreate("URE", eventName) :: UnreliableRemoteEvent
	ure:FireClient(player, ...)
end

--[=[
	@within NetworkServer
	@param eventName string -- Name of the `URE:eventName` UnreliableRemoteEvent.
	@param ... any -- Values to send.

	Fires an unreliable RemoteEvent to every connected client.

	```lua
	Network.broadcastUnreliable("WorldTick", tickData)
	```
]=]
local function broadcastUnreliable(eventName: string, ...: any)
	local ure = getOrCreate("URE", eventName) :: UnreliableRemoteEvent
	ure:FireAllClients(...)
end

--[=[
	@within NetworkServer
	@yields
	@param player Player -- The client to invoke.
	@param eventName string -- Name of the `RF:eventName` RemoteFunction.
	@param ... any -- Arguments forwarded to the client handler.
	@return ...any -- Values returned by the client handler.

	Invokes a RemoteFunction on a specific client and yields until the client responds.
	Avoid calling this in performance-critical paths; a client crash or disconnect will
	cause this to yield indefinitely unless wrapped in a `task.spawn` with a timeout.

	```lua
	local accepted = Network.invokeClient(player, "ConfirmTrade", tradeData)
	```
]=]
local function invokeClient(player: Player, eventName: string, ...: any): ...any
	local rf = getOrCreate("RF", eventName) :: RemoteFunction
	return rf:InvokeClient(player, ...)
end

--[=[
	@within NetworkServer
	@param opts { functions: { string }?, events: { string }?, unreliableEvents: { string }? } -- Names to eagerly create, grouped by remote type.

	Eagerly creates the underlying `RemoteFunction`, `RemoteEvent`, and `UnreliableRemoteEvent`
	instances for the supplied names so they exist in `ReplicatedStorage.Network` before any
	client tries to wait on them. Without this, remotes are created lazily on first use, which
	can race a client that's already calling `WaitForChild` (or [NetworkClient.on]). Safe to
	call multiple times — each name is cached after the first creation.

	```lua
	Network.setup({
		events = { "RoundStarted", "PlayerDied" },
		unreliableEvents = { "EnemyPosition" },
		functions = { "GetCoins" },
	})
	```
]=]
local function setup(opts: { [("functions" | "events" | "unreliableEvents")]: { string } })
	local functions = opts.functions
	local events = opts.events
	local unreliableEvents = opts.unreliableEvents

	if functions then
		for _, name in functions do
			getOrCreate("RF", name)
		end
	end

	if events then
		for _, name in events do
			getOrCreate("RE", name)
		end
	end

	if unreliableEvents then
		for _, name in unreliableEvents do
			getOrCreate("URE", name)
		end
	end
end

return {
	on = on,
	onUnreliable = onUnreliable,
	onInvoke = onInvoke,
	fireClient = fireClient,
	fireAllClients = fireAllClients,
	broadcast = broadcast,
	fireClientUnreliable = fireClientUnreliable,
	broadcastUnreliable = broadcastUnreliable,
	invokeClient = invokeClient,
	setup = setup,
}

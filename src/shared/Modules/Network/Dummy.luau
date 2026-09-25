--[=[
	@class NetworkDummy

	Drop-in replacement for the [Network] init module intended for Storybook stories and
	other client-only test environments where no real server or `ReplicatedStorage` exists.

	Both `server()` and `client()` return from the same shared bus, so events fired on one
	side are delivered synchronously to listeners on the other — no real remotes, no yielding.
	Disconnect functions returned by `on`, `onUnreliable`, and `onInvoke` behave identically
	to the real module.

	```lua
	local Network = require(script.Parent.Network.Dummy)

	local Server = Network.server()
	local Client = Network.client()

	Server.on("Ping", function(player, msg)
		Server.fireAllClients("Pong", msg .. " world")
	end)

	Client.on("Pong", function(msg)
		print(msg) --> "hello world"
	end)

	Client.fire("Ping", "hello")
	```
]=]

--[=[
	@interface DummyPlayer
	@within NetworkDummy
	.Name string
	.UserId number

	Minimal player-shaped table passed as the first argument to all server-side callbacks
	in place of a real `Player` instance.
]=]
export type DummyPlayer = {
	Name: string,
	UserId: number,
}

local DUMMY_PLAYER: DummyPlayer = {
	Name = "StoryPlayer",
	UserId = 0,
}

type Callback = (...any) -> ()
type Disconnect = () -> ()
type ListenerStore = { [string]: { Callback } }

local serverListeners: ListenerStore = {}
local serverUnreliableListeners: ListenerStore = {}
local serverInvokeHandlers: { [string]: Callback } = {}

local clientListeners: ListenerStore = {}
local clientUnreliableListeners: ListenerStore = {}

local function addListener(store: ListenerStore, eventName: string, callback: Callback): Disconnect
	if not store[eventName] then
		store[eventName] = {}
	end

	table.insert(store[eventName], callback)

	return function()
		local list = store[eventName]
		if not list then
			return
		end

		local index = table.find(list, callback)
		if index then
			table.remove(list, index)
		end
	end
end

local function fireListeners(store: ListenerStore, eventName: string, ...: any)
	local list = store[eventName]
	if not list then
		return
	end

	for _, callback in list do
		callback(...)
	end
end

-- ────────────────────────── Server ──────────────────────────

--[=[
	@within NetworkDummy
	@param eventName string -- Event name to listen on.
	@param callback (player: DummyPlayer, ...any) -> () -- Handler; receives [DummyPlayer] as the first argument.
	@return () -> () -- Disconnect function.

	Server-side equivalent of [NetworkServer.on]. Registers a listener that fires when
	[NetworkDummy.fire] is called on the client side.
]=]
local function serverOn(eventName: string, callback: (player: DummyPlayer, ...any) -> ()): Disconnect
	return addListener(serverListeners, eventName, callback :: Callback)
end

--[=[
	@within NetworkDummy
	@param eventName string -- Event name to listen on.
	@param callback (player: DummyPlayer, ...any) -> () -- Handler.
	@return () -> () -- Disconnect function.

	Server-side equivalent of [NetworkServer.onUnreliable].
]=]
local function serverOnUnreliable(eventName: string, callback: (player: DummyPlayer, ...any) -> ()): Disconnect
	return addListener(serverUnreliableListeners, eventName, callback :: Callback)
end

--[=[
	@within NetworkDummy
	@param eventName string -- Event name to handle.
	@param callback (player: DummyPlayer, ...any) -> ...any -- Handler whose return values are forwarded back to [NetworkDummy.invokeServer].
	@return () -> () -- Unregister function.

	Server-side equivalent of [NetworkServer.onInvoke].
]=]
local function serverOnInvoke(eventName: string, callback: (player: DummyPlayer, ...any) -> ...any): Disconnect
	serverInvokeHandlers[eventName] = callback :: Callback
	return function()
		if serverInvokeHandlers[eventName] == (callback :: Callback) then
			serverInvokeHandlers[eventName] = nil :: any
		end
	end
end

--[=[
	@within NetworkDummy
	@param _player DummyPlayer -- Ignored; present for API parity with [NetworkServer.fireClient].
	@param eventName string -- Event name.
	@param ... any -- Values delivered to client-side listeners.

	Delivers values to all client-side [NetworkDummy.clientOn] listeners for `eventName`.
]=]
local function fireClient(_player: DummyPlayer, eventName: string, ...: any)
	fireListeners(clientListeners, eventName, ...)
end

--[=[
	@within NetworkDummy
	@param eventName string -- Event name.
	@param ... any -- Values delivered to client-side listeners.

	Equivalent to [NetworkServer.fireAllClients]; delivers to all client-side listeners.
]=]
local function fireAllClients(eventName: string, ...: any)
	fireListeners(clientListeners, eventName, ...)
end

--[=[
	@within NetworkDummy
	@param eventName string -- Event name.
	@param ... any -- Values delivered to client-side listeners.

	Alias for [NetworkDummy.fireAllClients].
]=]
local function broadcast(eventName: string, ...: any)
	fireAllClients(eventName, ...)
end

--[=[
	@within NetworkDummy
	@param _player DummyPlayer -- Ignored; present for API parity.
	@param eventName string -- Event name.
	@param ... any -- Values delivered to client-side unreliable listeners.

	Unreliable variant of [NetworkDummy.fireClient].
]=]
local function fireClientUnreliable(_player: DummyPlayer, eventName: string, ...: any)
	fireListeners(clientUnreliableListeners, eventName, ...)
end

--[=[
	@within NetworkDummy
	@param eventName string -- Event name.
	@param ... any -- Values delivered to client-side unreliable listeners.

	Unreliable variant of [NetworkDummy.fireAllClients].
]=]
local function broadcastUnreliable(eventName: string, ...: any)
	fireListeners(clientUnreliableListeners, eventName, ...)
end

--[=[
	@within NetworkDummy
	@param _player DummyPlayer -- Ignored; present for API parity.
	@param eventName string -- Event name.
	@param ... any -- Arguments forwarded to the registered [NetworkDummy.serverOnInvoke] handler.
	@return ...any -- Return values from the handler, or nothing if no handler is registered.

	Synchronously calls the server's invoke handler and returns its result.
]=]
local function invokeClient(_player: DummyPlayer, eventName: string, ...: any): ...any
	local handler = serverInvokeHandlers[eventName]
	if handler then
		return handler(DUMMY_PLAYER, ...)
	end
	return
end

--[=[
	@within NetworkDummy
	@param _opts { functions: { string }?, events: { string }?, unreliableEvents: { string }? } -- Ignored; present for API parity with [NetworkServer.setup].

	No-op in the dummy bus — there are no real remotes to pre-create. Provided so
	server bootstrap code that calls `Network.server().setup({ ... })` keeps working
	in Storybook stories and other dummy environments.
]=]
local function setup(_opts: { [("functions" | "events" | "unreliableEvents")]: { string } }) end

-- ────────────────────────── Client ──────────────────────────

--[=[
	@within NetworkDummy
	@param eventName string -- Event name to listen on.
	@param callback (...any) -> () -- Handler.
	@return () -> () -- Disconnect function.

	Client-side equivalent of [NetworkClient.on]. Registers a listener that fires when the
	server calls [NetworkDummy.fireClient], [NetworkDummy.fireAllClients], or [NetworkDummy.broadcast].
]=]
local function clientOn(eventName: string, callback: (...any) -> ()): Disconnect
	return addListener(clientListeners, eventName, callback)
end

--[=[
	@within NetworkDummy
	@param eventName string -- Event name to listen on.
	@param callback (...any) -> () -- Handler.
	@return () -> () -- Disconnect function.

	Client-side equivalent of [NetworkClient.onUnreliable].
]=]
local function clientOnUnreliable(eventName: string, callback: (...any) -> ()): Disconnect
	return addListener(clientUnreliableListeners, eventName, callback)
end

--[=[
	@within NetworkDummy
	@param eventName string -- Event name.
	@param ... any -- Values delivered to server-side listeners with [DummyPlayer] prepended.

	Client-side equivalent of [NetworkClient.fire]. Synchronously delivers to all
	server-side [NetworkDummy.serverOn] listeners.
]=]
local function fire(eventName: string, ...: any)
	fireListeners(serverListeners, eventName, DUMMY_PLAYER, ...)
end

--[=[
	@within NetworkDummy
	@param eventName string -- Event name.
	@param ... any -- Values delivered to server-side unreliable listeners.

	Client-side equivalent of [NetworkClient.fireUnreliable].
]=]
local function fireUnreliable(eventName: string, ...: any)
	fireListeners(serverUnreliableListeners, eventName, DUMMY_PLAYER, ...)
end

--[=[
	@within NetworkDummy
	@param eventName string -- Event name.
	@param ... any -- Arguments forwarded to the registered [NetworkDummy.serverOnInvoke] handler.
	@return ...any -- Return values from the handler, or nothing if no handler is registered.

	Client-side equivalent of [NetworkClient.invokeServer]. Synchronously calls the
	server's invoke handler and returns its result.
]=]
local function invokeServer(eventName: string, ...: any): ...any
	local handler = serverInvokeHandlers[eventName]

	if handler then
		return handler(DUMMY_PLAYER, ...)
	end

	return
end

-- ─────────────────────────────────────────────────────────────

return {
	server = function()
		return {
			on = serverOn,
			onUnreliable = serverOnUnreliable,
			onInvoke = serverOnInvoke,
			fireClient = fireClient,
			fireAllClients = fireAllClients,
			broadcast = broadcast,
			fireClientUnreliable = fireClientUnreliable,
			broadcastUnreliable = broadcastUnreliable,
			invokeClient = invokeClient,
			setup = setup,
		}
	end,
	client = function()
		return {
			on = clientOn,
			onUnreliable = clientOnUnreliable,
			fire = fire,
			fireUnreliable = fireUnreliable,
			invokeServer = invokeServer,
		}
	end,
}

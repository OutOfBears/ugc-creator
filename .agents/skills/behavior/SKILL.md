---
name: behavior
description: Scaffold a paired Server<Name>/Client<Name> behavior following this repo's exact conventions. Use when adding new entity behavior, creating a behavior, or the user says "new behavior", "scaffold a behavior", or "add a Server/Client pair".
---

# Scaffold a behavior pair

Entity behavior in this repo is a paired `Server<Name>` + `Client<Name>` behavior sharing
one tag, registered through the in-repo Behavior system. A behavior is a Unity-style class
attached to an instance via a CollectionService tag, using attributes for replicated state.
This skill generates both files in the canonical shape so there's no boilerplate drift.

## Before writing

Confirm (ask only if not already clear from the request):

1. **Name** — PascalCase, no prefix (e.g. `Turret`). Files become `ServerTurret.luau` /
   `ClientTurret.luau`; the shared tag is `"Turret"`.
2. **instanceType** — the Roblox class the tag attaches to. `"Instance"` (default),
   `"Model"`, `"BasePart"`, `"Configuration"` (common for replicated entities), etc.
3. **Replicated?** — `true` (default) gives the server an `AttributeReplicator` and the
   client read access to the same `state` table. `false` = local-only, constructor takes
   just `(instance)`.
4. **State fields** — if replicated, the initial `state` table (server → client).
5. **Lifecycle** — which framework hooks it needs: `onStart` (once, after construction),
   `onHeartbeat(dt)`, `onStepped(time, dt)`, or `onRenderStepped(dt)` (client only).
   Implement only the hooks the behavior actually uses.

Don't invent fields, methods, or config the user didn't ask for (AGENTS.md §2).

## Lifecycle (framework-driven)

The Behavior factory drives a Unity-like lifecycle — you do **not** wire your own RunService
loops:

- `onStart(self)` — called once (via `task.spawn`) after every behavior on the frame is
  constructed. Use it for setup that may yield.
- `onHeartbeat(self, dt)` — auto-connected to `RunService.Heartbeat` if implemented.
- `onStepped(self, time, dt)` — auto-connected to `RunService.Stepped` if implemented.
- `onRenderStepped(self, dt)` — auto-connected to `RunService.RenderStepped` if implemented.
  **Client only** — the factory skips it on the server.
- `destroy(self)` — called on cleanup, after the framework disconnects the hook connections.

## Querying other behaviors

A behavior builds its object by calling `BehaviorBase(instance, replicator)` from
`require(ReplicatedStorage.Shared.Modules.Behavior.BehaviorBase)`. That constructor returns the
object already wired with `instance`, `replicator`, and the shared `self:` query surface — the
behavior then adds its own fields and returns it. There is no base class to compose and no
framework post-attach; everything lives on the object:

- `self:getBehavior(class)` — the behavior of `class` on this instance, or nil.
- `self:findBehavior(class)` — walk up ancestors from this instance to the nearest match.
- `self:getBehaviorsWithTag(tag)` — a behavior **pair** (all classes sharing a tag on this
  instance).
- `self:getBehaviorsOnInstance()` — every behavior on this instance.
- `self:waitForBehavior(class)` — a Promise resolving when the behavior attaches.

Non-behavior code (services, controllers, hooks) queries at module scope through
`require(ReplicatedStorage.Shared.Modules.Utils.Behaviors)` — same functions with an explicit
`instance` first argument, plus the global `Behaviors.getBehaviorsOfClass(class)`.

## Networking a pair

A behavior calls a method on its cross-realm pair through the `self:` methods `BehaviorBase`
wired onto it — never raw RemoteEvents. The call runs `executables[method]` on every
behavior sharing the tag on that instance in the other realm:

- Server → client: `self:fireClient(player, method, ...)` (pass `nil` player to fire all clients).
- Client → server: `self:fireServer(method, ...)`.

Expose the callable surface with an `executables` table on the object — the server receiver is
passed `(player, ...)`, the client receiver `(...)`:

```lua
object.executables = {
	playEffect = function(...) end,
}
```

## Conventions (match these exactly)

- `UPPER_SNAKE_CASE` module-level constants; `camelCase` locals and methods;
  `camelCase` for private/internal fields; `PascalCase` for types.
- **Functional class**: the constructor builds `local object = BehaviorBase(instance, replicator) :: Type`,
  attaches methods with `function object:method()`, and returns `object`. No `setmetatable`, no OOP.
- Use `task.wait` / `task.spawn` / `task.defer` — never `wait` / `spawn`.
- Use a `Maid` for any connections/instances the behavior owns; clean it in `destroy`.
- Replicated state goes in the behavior `state` / `replicator`, not `instance:SetAttribute`.
- Networking only via `self:fireClient` / `self:fireServer` (wired by `BehaviorBase`) —
  never raw RemoteEvents or `Network` directly from a behavior.
- **Reuse before writing (DRY):** check the reuse index in AGENTS.md §5 before adding any
  helper. Logic specific to this behavior stays a method on the object; don't add loose
  module-level functions. Named numeric/config constants belong in a `Data/` module, not
  as `local UPPER_SNAKE` at the file top — see AGENTS.md §5.
- **Comments (AGENTS.md §5):** keep inline comments minimal. Any public method you add to the
  `-- methods` type section gets a `@within` Moonwave block; lifecycle hooks (`onStart` /
  `onHeartbeat` / `onStepped` / `onRenderStepped` / `destroy`) stay bare.

## Server template — replicated

Path: `src/server/Behaviors/Server<Name>.luau`

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Behavior = require(ReplicatedStorage.Shared.Modules.Behavior)
local BehaviorBase = require(ReplicatedStorage.Shared.Modules.Behavior.BehaviorBase)
local AttributeReplicator = require(ReplicatedStorage.Shared.Modules.AttributeReplicator)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)

type Base<I> = Behavior.BehaviorBase<I>

type <Name>State = {
	example: number,
}

type Replicator = AttributeReplicator.AttributeReplicator<<Name>State, Configuration>

export type Server<Name> = Base<Instance> & {
	-- vars
	replicator: Replicator,
	-- methods
	destroy: (self: Server<Name>) -> (),
}

--[=[
	@class Server<Name>
	@server
]=]
local function Server<Name>(instance: Configuration, replicator: Replicator)
	local maid = Maid.new()
	local object = BehaviorBase(instance, replicator) :: Server<Name>

	function object:onStart() end

	function object:destroy()
		maid:DoCleaning()
	end

	return object
end

return Behavior("<Name>", Server<Name>, {
	state = { example = 0 },
	instanceType = "Configuration",
	replicated = true,
})
```

## Client template — replicated

Path: `src/client/Behaviors/Client<Name>.luau`

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Behavior = require(ReplicatedStorage.Shared.Modules.Behavior)
local BehaviorBase = require(ReplicatedStorage.Shared.Modules.Behavior.BehaviorBase)
local Maid = require(ReplicatedStorage.Shared.Modules.Maid)

type Base<I> = Behavior.BehaviorBase<I>

export type Client<Name> = Base<Instance> & {
	-- vars
	-- methods
	destroy: (self: Client<Name>) -> (),
}

--[=[
	@class Client<Name>
	@client
]=]
local function Client<Name>(instance: Configuration)
	local maid = Maid.new()
	local object = BehaviorBase(instance) :: Client<Name>

	function object:onStart() end

	function object:destroy()
		maid:DoCleaning()
	end

	return object
end

return Behavior("<Name>", Client<Name>, {
	instanceType = "Configuration",
	replicated = true,
})
```

For **non-replicated** behaviors: drop the `replicator` param and the `<Name>State` /
`Replicator` types, change the constructor signature to `(instance: <InstanceType>)`, drop
`state` from the config, and set `replicated = false`.

## After writing

Run the `/check` skill on the two new files before declaring done.

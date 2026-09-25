---
name: service-controller
description: Scaffold a long-lived server Service or client Controller following this repo's Loader conventions. Use when adding a server system, a client system, a background loop, or the user says "new service", "new controller", "add a service/controller", or "system that runs every frame".
---

# Scaffold a Service or Controller

Server **Services** (`src/server/Services/`) and client **Controllers**
(`src/client/Controllers/`) are the **same shape** — both are `LoaderModule` singletons
(`Types.Service` and `Types.Controller` are aliases). The `Loader` auto-discovers every
ModuleScript in the folder, so creating the file is the only registration step.

Confirm before writing: **server Service or client Controller?** (decides the folder and the
`Types.Service` vs `Types.Controller` annotation), the **name**, and whether it needs a
**per-frame loop** or just **init/run** logic.

## Shape

- A singleton **table**, not a constructor: `local FooService = {} :: Types.Service`,
  `return FooService` at the end. No functional-class `object` here (that's for Components).
- Methods and properties are `camelCase`. Expose signals/state as typed fields on the table.
- Require dependencies at the top by path; call other services/controllers directly.

## Lifecycle methods (all optional — define only what you need)

The Loader calls them in this order, sorted by `priority` (default 0):
- `onInit()` — synchronous setup. **All** modules' `onInit` finish before any `onRun`.
  Higher `priority` runs first.
- `onRun()` — async startup; wrapped in a Promise and fire-and-forget (errors are warned).
  Connect signals / start work here.
- `onStepped(time, dt)` / `onRenderStepped(dt)` / `onHeartbeat(dt)` — frame loops, wired
  through a pooled connection. Within a frame, **higher `priority` runs first**.

Set `priority` only when ordering against another module actually matters; say why.

## Template — `src/server/Services/<Name>Service.luau` (or `src/client/Controllers/<Name>Controller.luau`)

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

--[=[
	@class <Name>Service
	@server
]=]
local <Name>Service = {} :: Types.Service

function <Name>Service.onInit()
	-- synchronous setup
end

function <Name>Service.onRun()
	-- connect signals / start work
end

return <Name>Service
```

For a per-frame system, add a loop method instead of (or alongside) `onRun`:

```lua
local <Name>Service = {} :: Types.Service
<Name>Service.priority = 2 -- only if ordering matters

function <Name>Service.onStepped(_, dt: number)
	-- runs every frame
end

return <Name>Service
```

To expose a signal, widen the type and use the `Signal` package:

```lua
local Signal = require(ReplicatedStorage.Packages.Signal)

local <Name>Service = {} :: Types.Service & {
	somethingHappened: Signal.Signal<Player>,
}

--[=[
	@within <Name>Service
	@prop somethingHappened Signal.Signal<Player>

	Fires when something happens, passing the responsible player.
]=]
<Name>Service.somethingHappened = Signal.new()
```

(For a **Controller**, swap the folder, the `Service` suffix → `Controller`,
`Types.Service` → `Types.Controller`, and the `@server` realm tag → `@client`. Everything else
is identical.)

## Conventions

- Reuse before writing (AGENTS.md §5): events via `ServerEvents` / `ClientEvents` or
  `EventBus`; spatial via `EntityGrids` / `SpatialGrid`; game state via `GameStateReplicator`
  / charm atoms. Don't add a standalone helper a util already covers.
- Named numeric/config constants go in a `Data/` module, not as `local UPPER_SNAKE` at the
  file top (only structural literals like string tags stay inline) — see AGENTS.md §5.
- `task.*` not `wait`/`spawn`; guard nil-ables; never raw RemoteEvents (use `Network`).
- Comments (AGENTS.md §5): keep inline comments minimal. Public methods/signals get a
  `@within` Moonwave block; lifecycle methods (`onInit` / `onRun` / `onStepped`) stay bare.

## After writing

Run `/check` on the new file. Verify the `Signal` (and any other Package) require alias
against a neighbouring service/controller — names come from `wally.toml`.

---
name: ui
description: Scaffold React UI (jsdotlua/react + charm + react-flow) following this repo's conventions — a View, a reusable Component, a Context, or a Story. Use when adding UI, an interface, a HUD element, a screen, sharing values across a subtree, or the user says "new view", "UI component", "scaffold UI", "add a story", "react context", or "react".
---

# Scaffold React UI

UI lives in `src/interfaces/` (mounts to `ReplicatedStorage.Interfaces`) and uses
`jsdotlua/react` + `littensy/charm` for state, with `outofbears/react-flow` (`ReactFlow`)
for animation. Pick the artifact you're creating: **View**, **Component**, **Context**, or
**Story**.

Stack facts that decide the shape:
- **View** = a top-level screen in `src/interfaces/Views/`. `UIController` auto-discovers
  every ModuleScript there, wraps it in its own `ScreenGui`, and renders it with a
  `playerGui` prop. No registration needed — creating the file is enough.
- **Component** = a reusable, **memoized**, pure-presentation piece in
  `src/interfaces/Components/`. It takes all state via props (no atom subscriptions) and
  accepts an optional `native` prop merged over its defaults with `Sift.Dictionary.join`.
- **Context** = a `React.createContext` + Provider in `src/interfaces/Contexts/`, paired with
  a `useX` hook in `Hooks/`. For a **stable structural value a subtree shares** — theme, the
  active item's identity, feature config — that you'd otherwise prop-drill. **Not** for
  reactive game state (that stays in charm atoms; see the boundary below the template).
- **Story** = a UILabs preview in `src/interfaces/Stories/` named `<Component>.story.luau`.

Reuse first (CLAUDE.md §5): consume state through the existing hooks in
`src/interfaces/Hooks/` — `useAtom`, `useAtomBinding`, `useEvent`, `useLatest`, `useVisible`,
`useMousePosition`, `useFontScale`, `useTheme`, `useCreationSession` — and animate with
`ReactFlow.useTween` / `useSpring`. Don't hand-roll what a hook already gives you.

## Creation editor specifics

- **Styling is inline props from `useTheme()`** — `theme.tokens` (`Shared/Data/StyleTokens`
  `.style`), `theme.fonts`, and `theme.layout` (`Shared/Data/StyleLayouts`, mobile or desktop).
  There are no tags or StyleSheets: padding, list layouts, corners, strokes and flex items are
  explicit child elements, and any value you would name comes from a token.
- **Session-scoped Views** wrap their content in `Views/Creation/SessionGate`, which renders
  nothing without an open session and otherwise provides `CreationScope` keyed by the session.
  Below it, `useCreationSession()` reaches the tools and `useTheme()` the tokens. A View sets its
  own ScreenGui's display order, insets and `Enabled` with `useScreenGui(props.playerGui, {...})`.
- **Tool state** comes from a tool's `state` atom (e.g. `LayersTool.state`, an immutable
  snapshot republished after each change) via `useAtom`. Call tool methods from event handlers;
  never call tool methods from effect cleanups — the session tears its tools down itself.
- **Screen sub-views** that subscribe to atoms but aren't top-level screens go in
  `src/interfaces/Views/Creation/` — a plain folder, so `UIController` doesn't mount them.
- **Per-frame values** (drag positions, handles, canvas cursor) go through `useBinding` /
  `useAtomBinding`, never `useState`.

**Components: reuse, then generalize, never duplicate.** Before scaffolding a Component,
search `src/interfaces/Components/` for one that already renders this shape and use it —
`Health` reuses `HealthBar` twice with different props; `Backpack` renders many `BackpackItem`s
from data. When a layout repeats (a row of slots, a list of cards, N buttons), build **one**
generic, prop-driven Component and render the set from a data array with a key per item —
never copy-paste the subtree. Every difference between instances is a prop, so a Component
stays pure and memoizable.

Named numeric/config constants (durations, sizes, colors, thresholds you'd name) go in a
`Data/` module, not as `local UPPER_SNAKE` at the file top — see CLAUDE.md §5. Inline layout
literals inside `createElement` are fine.

## View template — `src/interfaces/Views/<Name>.luau`

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientAtoms = require(ReplicatedStorage.Client.Modules.ClientAtoms)
local React = require(ReplicatedStorage.Packages.React)

local useAtom = require("../Hooks/useAtom")

local createElement = React.createElement

export type <Name>Props = {
	playerGui: PlayerGui,
}

local function <Name>(_: <Name>Props)
	-- pull reactive state via hooks, e.g.:
	-- local character = useAtom(ClientAtoms.character)

	return createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {})
end

return <Name>
```

Views are **not** memoized and return the function directly. Require sibling components with
`require("../Components/<Name>")` and hooks with `require("../Hooks/<useX>")`.

## Component template — `src/interfaces/Components/<Name>.luau`

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Sift = require(ReplicatedStorage.Packages.Sift)

local createElement = React.createElement
local memo = React.memo

export type <Name>Props = {
	native: { [string]: any }?,
}

local <Name> = memo(function(props: <Name>Props)
	return createElement(
		"Frame",
		Sift.Dictionary.join({
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, props.native or {}),
		{}
	)
end)

return <Name>
```

Components are **memoized** and **pure** — every input arrives as a prop; no atom/replicator
subscriptions inside a Component (do that in the View and pass values down). Always include
the optional `native` prop and merge it last so callers can override layout.

For animation, pull a binding from ReactFlow and map it onto a property:

```lua
local ReactFlow = require(ReplicatedStorage.Packages.ReactFlow)
local sizeAnim, playSize = ReactFlow.useTween({ start = 0, target = 1, info = TWEEN_INFO })
-- Size = sizeAnim:map(function(v) return UDim2.fromScale(v, v) end)
```

## Context template — `src/interfaces/Contexts/<Name>Context.luau`

A Context is two files: the context module (below) and a paired read-hook in `Hooks/`. The
module owns a `createContext` with a sane `DEFAULT` (used when no Provider is mounted) and a
typed Provider wrapper.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local createContext = React.createContext
local createElement = React.createElement

export type <Name> = {
	-- the stable values this subtree shares, e.g. accent: Color3,
}

local DEFAULT: <Name> = {
	-- fallback used when a consumer renders with no Provider above it
}

local <Name>Context = createContext(DEFAULT)

export type <Name>ProviderProps = {
	value: <Name>,
	children: React.ReactNode,
}

local function <Name>Provider(props: <Name>ProviderProps)
	return createElement(<Name>Context.Provider, {
		value = props.value,
	}, props.children)
end

return {
	Context = <Name>Context,
	Provider = <Name>Provider,
	default = DEFAULT,
}
```

Paired hook — `src/interfaces/Hooks/use<Name>.luau`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local <Name>Context = require("../Contexts/<Name>Context")

local useContext = React.useContext

local function use<Name>()
	return useContext(<Name>Context.Context)
end

return use<Name>
```

The View (or whichever Component owns the value) wraps its subtree once —
`createElement(<Name>Context.Provider, { value = … }, { … })` — and nested Components read it
with `use<Name>()` instead of receiving it through every layer.

**Context vs charm — keep the line sharp.** charm atoms + the existing hooks stay the home for
global, reactive game state (score, level, currency, selected item). React Context is only for
**stable, structural** values a subtree shares — theme/palette, the active panel's identity,
feature config — that would otherwise be prop-drilled. This is a deliberate, narrow exception
to "every input is a prop" (Components above): it's safe **because the value is stable**, so it
doesn't churn memoization the way pushing a live atom into a leaf would. Reading live game
state is still an atom/replicator hook in the View, never a context.

## Story template — `src/interfaces/Stories/<Name>.story.luau`

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)

local <Name> = require("../Components/<Name>")

return {
	react = React,
	reactRoblox = ReactRoblox,
	controls = {
		-- e.g. transparency = UILabs.Slider(0, 0, 1, 0.1),
	},
	story = function(props: { controls: any, target: Frame })
		return React.createElement(<Name>, {
			native = { Size = UDim2.fromScale(0.3, 0.3) },
		})
	end,
}
```

## After writing

Run `/check` on the new file(s). Confirm the exact require alias for any Package
(`React`, `Sift`, `ReactRoblox`, `UILabs`, `ReactFlow`) against a neighbouring file — names
come from `wally.toml`, don't guess them.

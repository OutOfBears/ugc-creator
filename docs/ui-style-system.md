---
sidebar_position: 2
---

# UI style system

The creation editor's UI is a CSS-like styling system built on Roblox's
[StyleSheet API](https://create.roblox.com/docs/ui/styling). Components are tagged with string
ids; a rules table maps those tags to GUI properties. Component code stays focused on structure
and behaviour, and every visual decision lives in one place.

## Layout

Everything lives under `src/client/Modules/UI/`:

| Folder | What it is |
|---|---|
| `Components/` | Reusable building blocks — panels, buttons, pickers, sliders. They depend only on `Style/` and on each other. |
| `Style/` | The styling system itself: constants, rules, themes, and the style manager. |
| `Handlers/` | Experience-specific wiring between components and the editor's tools, managers, and data. |

`Components/` and `Style/` are portable — they can be lifted into another experience as they
are, given the `Shared/Data` modules they read tokens and icons from. `Handlers/` is not: it is
written against this game's tool and model interfaces. The exception is `Handlers/ExampleUI`, a
template showing how to build a handler on top of this system.

`Handlers/BaseUI` is the entry point. It constructs the shared style manager and owns the other
handlers.

## The Style files

### `StyleConsts`

Structural constants that stay with the UI layer:

- **`tags`** — the closed set of tag ids a component may carry (`StyleConsts.tags.Panel`). Use
  these rather than raw strings. The values are load-bearing: `StyleRules` selects on them
  verbatim, so a tag string can be added but never reworded.
- **`regionOrdering`** / **`modelDisplayName`** — ordering and labels for the body regions the
  creation UI offers.
- **`mobileWidthCutoff`** — the screen size below which the mobile theme applies.
- **`defaultColorPickerColor`** — the HSV triple `ColorPicker` opens on.

Design tokens and image ids are **not** here — they are data, and live in
`ReplicatedStorage.Shared.Data`:

| What | Where |
|---|---|
| Colors, strokes, spacing, radii, component sizes | `StyleTokens.style` |
| BuilderSans font + size pairings | `StyleTokens.fonts` |
| Tool, editor, widget and region icons; UI chrome images | `CreationIcons` |
| Scroll bar slice images | `CreationIcons.scrollBar` |

### `StyleRules`

Every rule in the UI, as selector-to-property tables grouped by component
(`PANEL_RULES`, `COLOR_PICKER_RULES`, …). Three sets are exported, and `StyleSheet` compiles
them at ascending priority:

| Export | Priority | Purpose |
|---|---|---|
| `lowPriorityRules` | 0 | Broad defaults by class name, e.g. every `TextLabel`. |
| `standardRules` | 50 | Component rules, compiled from every table listed in `RULES`. |
| `highPriorityRules` | 100 | State overrides that must win, e.g. `ButtonSelected`, `Hidden`. |

### `StyleThemes`

The mobile and desktop token sets. A theme token is an attribute set on a `StyleSheet`
instance, which a rule reads back with the `${Token}` syntax — that indirection is how one rule
produces two layouts. Every theme table must define a value for every key in `themeTokens`; a
missing one leaves the rule's `${Token}` unresolved.

### `StyleSheet`

The style manager. Constructing it creates the core `StyleSheet` instance, both theme sheets,
and the `StyleDerive` that points at whichever theme is active, then generates all the rules.

```lua
local StyleSheet = require(ReplicatedStorage.Client.Modules.UI.Style.StyleSheet)

local style = StyleSheet()
style:linkGui(screenGui)
```

`linkGui` parents a `StyleLink` into the ScreenGui and watches its `AbsoluteSize`, swapping the
theme as the screen resizes. Call it for every ScreenGui that should be styled — they all share
one manager. `destroy` tears down the sheets and the size connections.

### `StyleUtils`

`addStyleTag` / `removeStyleTag` wrap `AddTag` / `RemoveTag` with a nil guard and a warning that
names the component — worth having, because a nil tag otherwise fails silently mid-build.
`getIsMobile` and `getMousePositionScaleOnComponent` are the screen-size and pointer maths the
components share.

## Using it

A component tags itself at construction — `Create` takes a `Tags` list — and handlers tag
components they want in a particular state:

```lua
local StyleConsts = require("../Style/StyleConsts")
local StyleUtils = require("../Style/StyleUtils")

local frame = Create("Frame", {
	Name = "Panel",
	Tags = { StyleConsts.tags.Panel },
})

StyleUtils.addStyleTag(button, StyleConsts.tags.ButtonSelected)
StyleUtils.removeStyleTag(button, StyleConsts.tags.ButtonSelected)
```

Tagging is reactive: a rule applies the moment the tag lands, whatever order construction and
parenting happened in.

## Adding a rule

1. Add the tag to `StyleConsts.tags` if the component needs a new one.
2. Add the selector and its properties to the matching table in `StyleRules` — or start a new
   table and list it in `RULES`, which is what `standardRules` compiles from.
3. If the property must differ between mobile and desktop, do not branch in the rule. Add a key
   to `THEME_TOKENS` in `StyleThemes`, give it a value in **both** theme tables, and reference
   it from the rule as `` `${themeTokens.YourToken}` ``.
4. Tag the component.

Selectors follow Roblox's styling syntax: `.Tag` matches a tagged instance, `.Tag > ClassName`
its children of that class, `.Tag::UIPadding` a pseudo-instance the sheet creates and manages,
and a comma separates alternatives.

## Component shape

Components come in two shapes, and both modules return a single function.

**Factories** return a GUI instance directly:

```lua
local Overlay = require("./Overlay")

local overlay = Overlay()
overlay.Parent = screenGui
```

**Functional classes** return an object carrying `frame` (or, for `EditHandle`, `moveHandle`),
a `maid`, and the methods that drive it. They own their instances and connections and clean up
in `destroy`:

```lua
local Slider = require("./Slider")

local slider = Slider(0.5, function(value, isFinalInput) end)
slider.frame.Parent = toolFrame
-- later
slider:destroy()
```

The class-shaped components are `ColorPicker`, `Counter`, `EditHandle`, `HorizontalPillbar`,
`ItemSelector`, `MiniBaseTileGroup`, `Panel`, `ProgressBar`, `SegmentedControl`, `Slider`,
`Toolbar` and `ToolbarButtonGroup`. Everything else is a factory.

## Handler architecture

`Handlers/` is the experience-specific half of the UI. Each handler builds one or more
ScreenGuis and wires `Components/` to the session, tool and `ModelInfo` interfaces behind
them. `Components/` and `Style/` depend only on each other and port to any experience;
handlers do not.

[BaseUI](../src/client/Modules/UI/Handlers/BaseUI.luau) is the entry point. It constructs the
shared `StyleSheet` that every other handler links its gui into, and it owns and destroys the
rest: `TopBarUI`, `EditingUI`, `PreviewUI`, `ResetEditsModalUI` and
`AccessoryAdjustmentModalUI`. It also holds the editor-scoped display state — landscape
orientation, core gui and chat disabled, jumping disabled — and restores all of it on
`destroy`. `EditingUI` in turn owns the six tool panels and the toolbar that opens them.

`SwitchEditorsModalUI` is the one exception to that ownership tree:
[CreationController](../src/client/Controllers/CreationController.luau) builds it before any
editor exists, so it takes a `StyleSheet` as its first argument instead of reading one off
`BaseUI`.

Handlers instantiate components directly, following the factory/class split described above.
Styling applies automatically once a component's instances are tagged (`StyleUtils.addStyleTag`,
or `Tags` on `Create`) and its gui is linked via `style:linkGui`.

`ExampleUI` is the one portable handler — a template for building a new one against this Style
system. Nothing in the experience constructs it.

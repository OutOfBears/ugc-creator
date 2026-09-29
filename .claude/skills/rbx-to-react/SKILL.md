---
name: rbx-to-react
description: Convert a Roblox Studio GuiObject tree into a jsdotlua/react component for this repo. Use when the user has UI built as instances in Studio and wants it as React, says "rbx to react", "instance to react", "serialize this UI", "convert the GUI to React", or "turn the StarterGui frame into a component".
---

# Roblox instance → React UI

Transcribe a GuiObject tree that exists in a live Studio session into a `createElement`
component that matches this repo's UI conventions. The job splits into a **deterministic
extraction** half (run a fixed serializer, never improvise property reads) and a
**constrained codegen** half (follow the mapping table, never freehand React). Pinning both
is what keeps the output faithful instead of plausible-but-wrong.

Requires the Roblox Studio MCP connected (`mcp__Roblox_Studio__*`) with a Studio session
holding the UI. No HTTP — property reflection comes from the engine's `ReflectionService`.

## 1. Locate the root — don't guess the path

Use `mcp__Roblox_Studio__search_game_tree` to find the GuiObject root by name and resolve its
full dotted path (e.g. `game.StarterGui.HUD.Root`). Confirm it's the intended node before
extracting. If multiple Studios are open, `set_active_studio` first.

## 2. Serialize the whole tree in ONE call

Read [serialize.luau](serialize.luau), set its `ROOT_PATH` to the path from step 1, and run
the whole script through `mcp__Roblox_Studio__execute_luau`. It returns one JSON object —
`{ viewport = {w, h}, tree = <root> }` — where every node is
`{ class, name, props, children, absSize?, absPos? }`, covering the root and every descendant.

How it works (so you can reason about its output, not just trust it):
- **Reflection comes from `ReflectionService`**, not a hardcoded list. For each class it calls
  `ReflectionService:GetPropertiesOfClass(className)` (inherited properties included by
  default) and keeps only entries that are `Serialized == true` (serializable), have a
  `Permits.Write` security context (writable), and carry no `Display.DeprecationMessage`
  (not deprecated). The per-class result is memoized in a `local` table for the duration of
  the run — no `_G`, no HTTP, no API dump.
- **Only non-default properties are emitted** — each value is diffed against a fresh
  `Instance.new(ClassName)` so you get signal, not a wall of engine defaults. This is a
  guarantee you can lean on in step 3.
- **Values are type-tagged** (`__t`) so `UDim2`/`Color3`/`Vector2`/`Enum`/`Font`/sequences
  survive JSON. See the mapping table below for how each tag becomes a Luau literal.
- **Children are in order**, filtered to `GuiObject` + `UIComponent` (so `UIListLayout`,
  `UIStroke`, `UIFlexItem`, constraints, gradients, etc. are included — they're the easiest
  thing to silently drop).
- **Layout context is captured for responsive work** — the root reports the authoring
  `viewport` size and each node its rendered `absSize`/`absPos` (when available). Step 4 uses
  these to rebuild the layout as scale-based, all-device UI instead of one device's offsets.

If the return is truncated (very large tree) or `execute_luau` rejects a big payload, narrow
`ROOT_PATH` to a subtree and run it per branch, or lower `MAX_NODES`. Reflection is in-engine
(no network), so re-running per branch is cheap.

## 3. Map each tagged value to a Luau literal — from this table, not memory

**Read every value straight from the serializer JSON (or a live Studio dump) — never from a
hand-written summary.** Do not condense the tree into your own notes and then code from *that*.
Flattening a deep tree by hand silently slides a child's `Size`/`Position` onto its parent — an
off-by-one-*level* error that renders as whole blocks mis-placed (empty gaps, shifted columns)
while every individual value still looks plausible. The raw JSON is the single source of truth;
pull each node's props directly from it. When the JSON is hard to read at depth and exact numbers
matter, get ground truth from the engine instead of eyeballing: run a small `execute_luau` that
walks the target subtree and prints each node's `Size`/`Position`/`AnchorPoint`, and copy those
values verbatim. Trust the engine's numbers, not your transcription.

| Serialized tag | React literal |
|---|---|
| plain string / number / boolean | as-is |
| `{__t:"UDim2", x:[s,o], y:[s,o]}` | `UDim2.new(s, o, s, o)` — keep both scale + offset, don't collapse to `fromScale` |
| `{__t:"UDim", s, o}` | `UDim.new(s, o)` |
| `{__t:"Vector2", x, y}` | `Vector2.new(x, y)` |
| `{__t:"Vector3", x, y, z}` | `Vector3.new(x, y, z)` |
| `{__t:"Color3", r, g, b}` | `Color3.fromRGB(r, g, b)` |
| `{__t:"Rect", min:[x,y], max:[x,y]}` | `Rect.new(min.x, min.y, max.x, max.y)` |
| `{__t:"NumberRange", min, max}` | `NumberRange.new(min, max)` |
| `{__t:"Enum", e:"Enum.X.Y"}` | `Enum.X.Y` |
| `{__t:"Font", family, weight, style}` | `Font.new(family, Enum.FontWeight.<weight>, Enum.FontStyle.<style>)` |
| `{__t:"ColorSequence", keypoints}` | `ColorSequence.new({ ColorSequenceKeypoint.new(t, Color3.fromRGB(r,g,b)), ... })` |
| `{__t:"NumberSequence", keypoints}` | `NumberSequence.new({ NumberSequenceKeypoint.new(t, v, env), ... })` |
| `{__t:"raw", s}` | an engine type the serializer didn't model — handle case-by-case or drop it; don't invent a value |

Each instance becomes `createElement(class, { props }, { childrenDict })`, where the children
dict is keyed by **camelCase versions of each child's `Name`** (`listLayout`, `innerBar`,
`textLabel`).

Rules on the props themselves:
- **Order them alphabetically** by key, matching this repo (HealthBar runs `AnchorPoint,
  BackgroundColor3, BackgroundTransparency, BorderColor3, BorderSizePixel, …`). JSON object
  key order is meaningless — sort it yourself; don't echo whatever order you received.
- **Never re-introduce a default.** The JSON already excludes every property still at its
  engine default (the serializer diffed it against `Instance.new(ClassName)`). If a property
  isn't in the JSON, don't write it — adding `BorderSizePixel = 0`, `Visible = true`, etc.
  back in is noise. Also normalize float-noise the designer left behind (`6.9e-08` → `0`).
- **Framed content images get `ScaleType = Fit`, even if the source left them `Stretch`.** When
  an image has an intrinsic aspect ratio and sits inside a frame — an avatar/headshot/portrait,
  a content thumbnail — set `ScaleType = Enum.ScaleType.Fit` so it isn't distorted; designers
  routinely leave these at the default `Stretch` and it's wrong. This is the one place to
  deliberately override the captured value. **Do not** touch decorative images — borders,
  background/slice art, gradients, glows are meant to fill, so keep their authored `ScaleType`
  (`Stretch`/`Slice`).
- **Pad evenly.** Designers often inset a single side (a lone `PaddingLeft`) or use mismatched
  values; normalize a container's `UIPadding` to one consistent amount across all four sides (or
  at minimum symmetric top/bottom and left/right) unless the design genuinely needs the
  asymmetry. Even insets read as intentional; one-sided padding reads as an accident.

## 4. Scale across devices — the capture is device-specific

The `viewport`, `absSize`, and `absPos` you captured describe the **one device the UI was
authored on**. Transcribed verbatim, an offset-based layout is wrong on every other screen.
Make it device-relative with this repo's idioms (see HealthBar.luau / Health.luau):

- **Prefer scale over offset.** Where an element should grow with its container, express
  `Size`/`Position` in scale: `scaleX = absSize.x / parentAbsSize.x` (use `viewport` at the
  root). Keep offset only for what must stay pixel-fixed — hairline borders, a few px of
  padding. Mixed `UDim2.new(scale, offset, scale, offset)` is normal here.
- **Lock proportions with `UIAspectRatioConstraint`** on any element whose shape must hold
  across aspect ratios (HealthBar pins `AspectRatio = 15`).
- **Scale text through `useFontScale`, never a hardcoded `TextSize`.** Take
  `local rem, em = useFontScale(ref)` and set `TextSize = em(n)` (parent-relative) or `rem(n)`
  (viewport-relative, baseline 1080p) — HealthBar uses `TextSize = em(60)`. Recover `n` from
  the captured `TextSize` against the element's scale.
- **Floor and cap with `UISizeConstraint`** (`MinSize`/`MaxSize`) so text and icons stay
  legible on phones and don't balloon on 4K — HealthBar sets a `MinSize`.
- `absSize` reflects the element as rendered in the current Studio viewport, so it's a real
  basis for the scale math. The captured `viewport` is that Studio window — treat it as the
  reference device the fractions are relative to, not a target phone/4K. A `{0, 0}` `absSize`
  means a genuinely collapsed or auto-sized element; fall back to its authored `UDim2` there.

Say which offsets you converted to scale and what device you assumed (CLAUDE.md §1) so the
user can confirm the responsive behavior.

## 5. Conform to repo conventions — reuse, generalize, contextualize

A serialized screen is one giant tree; don't transcribe it as one giant `createElement`.
Decompose it the way this repo does (run the `ui` skill's templates for the exact shapes):

- **Reuse before you generate.** Search `src/interfaces/Components/` first — if the tree
  contains a bar, card, slot, or button an existing Component already renders, use that
  Component with props instead of re-emitting its markup (`Health` reuses `HealthBar`;
  `Backpack` reuses `BackpackItem`). A match is the best outcome, not a fallback.
- **Collapse repetition into one generic Component.** Where the tree repeats a subtree — a row
  of slots, a list of cards, N identical buttons — build **one** memoized, prop-driven
  Component and render the set from a data array (children keyed per item), never copy-paste
  the subtree N times. Every difference between instances becomes a prop.
- **Stand up a Context instead of prop-drilling shared values.** If several nested pieces of
  the converted tree need the same stable value — an accent/theme, the panel's identity,
  feature config — scaffold a Context (+ paired `useX` hook) per the `ui` skill's Context
  template rather than threading it through every layer. Keep reactive game state in charm
  atoms/hooks; Context is for stable structural values only (the `ui` skill draws that line).
- **Components stay pure** — optional `native` prop merged last via `Sift.Dictionary.join`,
  subscriptions in the View. Hoist named numeric/config constants the design implies into a
  `Data/` module per CLAUDE.md §5; inline layout literals stay inline.
- Then run `/check` on the new files (selene + stylua hard gates).

## 6. Flag dynamic values — don't hardcode a frozen snapshot

The serializer captures the instance **as it sits right now**. Anything driven at runtime —
a health-bar fill, animated transparency, a count label, a `:map`'d spring (see HealthBar) —
arrives as a single frozen value. Do **not** silently bake those in. Mark each value that
looks like it should be reactive as a candidate **prop / binding** and confirm with the user
rather than guessing the data source. This is the one genuine judgment boundary in the
pipeline; surface it (CLAUDE.md §1).

## 7. Verify — render YOUR output and diff it, not just the source

A capture of the **source** GuiObject proves nothing about your React — it only proves you can
read the design. Verification means putting your **generated** component on screen and comparing
it against the source. A source-only screenshot is not a substitute and does not count as
verified.

The render needs the component synced into Studio — Rojo connected, `Interfaces` present in the
DataModel. Check first (`ReplicatedStorage:FindFirstChild("Interfaces")`); if it's absent you'll
render a stale or missing version, so sync before judging anything. Then pick one:

- **Render-and-diff (preferred):** mount the component in a Story (`/ui` Story template) or push
  it into a temp ScreenGui via `execute_luau`, `screen_capture` it, and place that next to a
  capture of the source GuiObject. The layouts must line up.
- **Re-serialize-and-diff (exact):** run `serialize.luau` against your rendered tree and diff the
  JSON against step 2's — same `Size`/`Position`/`children` per node, or the gap is a bug.

If you genuinely cannot render (no sync, MCP unavailable), say so plainly and report the
conversion as **unverified** — never imply a match you have not actually seen on screen.

**Done when:** your rendered output sits beside the source and they match, `/check` is clean on
the new files, and every non-default property in the JSON is either present in the React or
deliberately promoted to a prop (step 6).

---

Note: this skill's `serialize.luau` is tooling, not shipped game code — it lives outside
`src/`, so the `/check` gate doesn't cover it. Property reflection relies on
`ReflectionService:GetPropertiesOfClass` and the `Serialized` / `Permits.Write` /
`Display.DeprecationMessage` fields on each returned entry; if a future engine version
renames those, adjust the filter in `propsFor`.

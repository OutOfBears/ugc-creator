---
sidebar_position: 2
---

# UI architecture

The creation editor's UI is React ([jsdotlua/react](https://github.com/jsdotlua/react-lua)) with
[Charm](https://github.com/littensy/charm) atoms for state. It lives in `src/interfaces/`, which
mounts to `ReplicatedStorage.Interfaces`. Use the `/ui` skill to scaffold new pieces.

## Layout

| Folder | What it is |
|---|---|
| `Views/` | One module per ScreenGui. `UIController` mounts every module here into its own ScreenGui under a `UI` folder in PlayerGui; the view sets that ScreenGui's display order, insets and `Enabled` with `useScreenGui`. |
| `Views/Creation/` | Sub-views that subscribe to state but are not top-level screens: the tool panels and `SessionGate`. A plain folder, so `UIController` does not mount it. |
| `Components/` | Memoized, pure building blocks — `Panel`, `Toolbar`, `Slider`, `ColorPicker`, `Modal`, `EditHandle`, `UVCanvasView` and so on. Every input is a prop. |
| `Contexts/` | `ThemeContext` (tokens plus the mobile or desktop layout) and `CreationSessionContext`. |
| `Hooks/` | `useAtom` / `useAtomBinding`, `useTheme`, `useCreationSession`, `useScreenGui` and others. |

## Where state lives

- **Editor-wide:** `ClientAtoms` — the open `creationSession`, `isMobile` (from the viewport
  size), the loading cover, message banners and the switch-editors prompt.
- **Per session:** `CreationSession` holds `screen` (edit or preview), `modal` and
  `previewTarget`. `CreationPanels` holds which tool is active and whether the 2D canvas is on,
  and does the sequencing when a tool opens. `UVCanvas` holds the canvas window, zoom, pan and
  cursor.
- **Per tool:** each tool publishes what its UI shows as atoms — `LayersTool.state`,
  `StickerTool.state` and `handle`, `KitbashTool.pieceCount` and `handle`,
  `AccessorySwapTool.selections`, `BrushTool.captureEnabled`, and `MeshEditingWidgets`'
  widget entries and per-frame displays.

Views read state with `useAtom`, or `useAtomBinding` for anything that changes every frame
(window drags, handles, the brush cursor, mesh widgets), so per-frame updates never re-render.
They call tool or session methods from event handlers, never from effect cleanups; the session
tears its tools down itself.

Session views wrap their content in `SessionGate`, which renders nothing until a session opens and
remounts everything under a fresh key for each new session.

## Styling

There are no tags or StyleSheets. Components set properties inline from `useTheme()`:
`theme.tokens` and `theme.fonts` come from `Shared/Data/StyleTokens`, and `theme.layout` is the
mobile or desktop set from `Shared/Data/StyleLayouts`. A screen is mobile when both of its axes
are at or under `StyleLayouts.mobileWidthCutoff`. Padding, list layouts, corners, strokes and
flex items are explicit child elements.

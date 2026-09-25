# Asset relocation manifest

What to move in the place file so it matches the ported code.

Roblox's UGC template kept its models in four folders scattered across `ReplicatedStorage`
top level. The port consolidates all of them under a single `ReplicatedStorage.Assets` folder,
reached only through `AssetUtil.resolve(path)` in
[AssetUtil.luau](../src/shared/Modules/Utils/AssetUtil.luau).

`Assets` is declared in [default.project.json](../default.project.json) as a bare
`{ "$className": "Folder" }`. A node with `$className` and no `$path` defaults to
`$ignoreUnknownInstances: true`, so Rojo creates the folder and never touches what you put
inside it. **Nothing below is synced from disk — these are all place-file instances you move
by hand in Studio.**

---

## 1. Move into `ReplicatedStorage.Assets`

| Move this | To here | Read by |
|---|---|---|
| `ReplicatedStorage.Blanks` | `ReplicatedStorage.Assets.Blanks` | [Blanks/init.luau](../src/shared/Data/Blanks/init.luau) |
| `ReplicatedStorage.MeshEditControlGroups` | `ReplicatedStorage.Assets.MeshEditControlGroups` | [Blanks/init.luau](../src/shared/Data/Blanks/init.luau) |
| `ReplicatedStorage.KitbashPieces` | `ReplicatedStorage.Assets.KitbashPieces` | `KitbashTool` |
| `ReplicatedStorage.PreviewModels` | `ReplicatedStorage.Assets.PreviewModels` | `PreviewTool` |

Resulting shape:

```
ReplicatedStorage.Assets
├── Blanks/
│   ├── RobotModel            (Model)
│   ├── TShirtModel           (Model)
│   └── HatModel              (Model)
├── MeshEditControlGroups/
│   ├── RobotModel            (Folder)
│   ├── TShirtModel           (Folder)
│   └── HatModel              (Folder)
├── KitbashPieces/
│   ├── GooglyEye             (MeshPart)
│   ├── GooglyEyeAltPupil     (MeshPart)
│   ├── Button                (MeshPart)
│   ├── Spike                 (MeshPart)
│   ├── RedGemstone           (MeshPart)
│   ├── GoldGemstone          (MeshPart)
│   ├── PurpleGemstone        (MeshPart)
│   └── GreenGemstone         (MeshPart)
└── PreviewModels/
    └── Roxy                  (Model, needs a Humanoid)
```

The names above are **load-bearing** — they are looked up by string:
- `Blanks` / `MeshEditControlGroups` children must match the `name` field of each entry in
  [Blanks/init.luau](../src/shared/Data/Blanks/init.luau).
- `KitbashPieces` children must match the `name` field of each entry in
  [Kitbash.luau](../src/shared/Data/Kitbash.luau).

## 2. Leave in `Workspace` — do **not** move these

These are positional anchors; the code reads their `CFrame`, so they have to stay in the world.

| Instance | Used by |
|---|---|
| `Workspace.ModelPositionMarker` | `ModelInfo` — every mesh part is placed relative to it |
| `Workspace.PreviewPositionMarker1` | `PreviewTool` — the Roxy mannequin slot |
| `Workspace.PreviewPositionMarker2` | `PreviewTool` — the player-avatar slot |

## 3. Delete — no longer used

| Instance | Why |
|---|---|
| `ReplicatedStorage.Remotes` (all 8 remotes) | Replaced by the `Network` module, which creates its own remotes under `ReplicatedStorage.Network` at runtime. |
| `StarterGui.ScreenGui.LoadingScreen` | Now built in code — see [LoadingScreen.luau](../src/client/Modules/UI/LoadingScreen.luau). It was never mapped by any project file, so the old client hung on `WaitForChild` if it was missing. |
| `ReplicatedStorage.Modules` | The code moved into the repo tree. |
| `ServerStorage.Modules` | Same. |

**`StarterPlayer.StarterPlayerScripts.PlayerModule` stays.** It is now Rojo-managed, mounted from
[assets/PlayerModule.rbxm](../assets/PlayerModule.rbxm) by
[default.project.json](../default.project.json), so Rojo syncs it into the place — do not delete
it there and do not hand-edit it in Studio.

`CreationSession` requires it to disable the default character controls while the editor is open
(`playerControls():Disable()` / `:Enable()`). Relying on the engine's own injected copy is not
safe here: with a Rojo-managed `StarterPlayerScripts`, `Players.<name>.PlayerScripts.PlayerModule`
was not resolving at runtime.

`ServerStorage.ServerModelStorage` needs no action — `CreationService` creates it on demand.

## 4. Kiosks — retag before they work

The three ClickDetector scripts are gone, replaced by one behavior pair
([ServerCreationKiosk](../src/server/Behaviors/ServerCreationKiosk.luau) /
[ClientCreationKiosk](../src/client/Behaviors/ClientCreationKiosk.luau)).

For each of the three kiosk models in `Workspace.Structure`:

| Kiosk | Tag | `BlankName` attribute |
|---|---|---|
| `Avatars.world_ui_panel` | `CreationKiosk` | `RobotModel` |
| `Accessories.world_ui_panel` | `CreationKiosk` | `TShirtModel` |
| `RigidAccessories.world_ui_panel` | `CreationKiosk` | `HatModel` |

Then delete the old `Cube.ClickDetector.OnClicked*` scripts. Keep the `ClickDetector` itself —
the behavior finds it with `FindFirstChildWhichIsA("ClickDetector", true)`.

---

## 5. Internal structure the blanks must keep

Moving the folders does not change what has to be *inside* them. Recorded here because several
of these are asserted at runtime and fail loudly.

**Every blank model**
- Body blanks: `Torso` → `LowerTorso`; attachments carry an `OriginalPosition` value and a
  sibling `WrapDeformer`.
- Accessory blanks: a child `Accessory` whose `AccessoryType` matches the definition's
  `avatarAssetType` — [Blanks.get](../src/shared/Data/Blanks/init.luau) asserts on both, so a
  mismatch errors the moment a player opens that editor.
- Accessory handles: a MeshPart with a `WrapLayer`, an `Attachment`, an `AvatarPartScaleType`
  value, an `OriginalSize` value, and a `WrapTarget`.

**`TShirtModel` specifically** must keep the chain
`TShirtModel.ShirtAccessory.Shirt.TShirt_VNeck_001` — a MeshPart with a `WrapLayer` /
`ReferenceMeshContent`. Only `tools/UpdateReferenceCageMesh.luau` walks it, but that path is
a plain dot-chain with no `WaitForChild`, so it breaks silently.

**Mesh part names inside each blank**, referenced by
[RegionMaps.luau](../src/shared/Data/RegionMaps.luau):
- `RobotModel` — `Hair`, `Head`, `UpperTorso`, `LowerTorso`, `LeftHand`/`LeftLowerArm`/`LeftUpperArm`,
  `RightHand`/`RightLowerArm`/`RightUpperArm`, `LeftFoot`/`LeftLowerLeg`/`LeftUpperLeg`,
  `RightFoot`/`RightLowerLeg`/`RightUpperLeg`
- `TShirtModel` — `Shirt`
- `HatModel` — `Hat`

**Each `MeshEditControlGroups` child** (consumed by `MeshInfo`): control folders carrying a
`ControlType` StringValue (`"Line"` or `"Plane"`), control-point Parts `P1`–`P4`, a `Normal`,
an `Axis` and `AxisEnd`, and an optional `DeformsAdditionalParts` folder of StringValues naming
extra mesh parts to deform.

---

## 6. Publish tokens — required before publishing works

[CreationTokens.luau](../src/shared/Data/CreationTokens.luau) is keyed by **universe id** and
currently holds only the three universes Roblox shipped the template with. Publishing from this
place will fail until an entry for this universe's own id is added, with a `body` token and an
`accessories` token per `Enum.AvatarAssetType` you want to allow. Until then
`AvatarPublisher.getPrice` returns `0` and the buy button reads "Publish" rather than a price.

`tools/UpdateReferenceCageMesh.luau` also hardcodes `game.CreatorId == 3529469` and needs the
same treatment if you ever run it.

---

## 7. Asset ids that stay ids

Around 60 `rbxassetid://` image ids (toolbar icons, region masks, the 19 stickers) and the 8
`rbxthumb://` kitbash thumbnails are **not** instances — they live in
[CreationIcons.luau](../src/shared/Data/CreationIcons.luau),
[Stickers.luau](../src/shared/Data/Stickers.luau),
[RegionMaps.luau](../src/shared/Data/RegionMaps.luau) and
[Kitbash.luau](../src/shared/Data/Kitbash.luau). Nothing to move — but note they are uploaded
under Roblox's account. If any of them is private rather than public, re-upload it under this
place's creator and swap the id in the matching `Data/` module.

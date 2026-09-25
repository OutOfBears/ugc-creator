# UV Region Exporter

A Blender addon that lets an artist assign mesh faces to named **regions** (hair, eyes, muzzle,
inner ear, …) and export them as a compact base64 blob. The Luau runtime decodes the blob and
rasterizes each region's UV triangles into a per-texel mask — replacing the old flag-colored
region-mask *textures*, so there's no image asset to upload and nothing to get recompressed or
anti-aliased at region edges.

> Separate from the repo's `tools/` directory (Lune scripts). This `tool/` folder is the Blender
> exporter and its shared codec.

## Files

| File | Runs in | Purpose |
| --- | --- | --- |
| `uv_region_codec.py` | plain Python | Encode/decode the blob. No `bpy`, so it's unit-testable. |
| `__init__.py` | Blender | The addon: region list UI, face assignment, export. |
| `tests/test_codec.py` | plain Python | Round-trip test for the codec. |

The codec is the single source of truth for the byte format and is imported by both the addon and
the (future) build-time step that folds the blob into the runtime data.

## Install

Blender loads this as a **package** (folder with `__init__.py`), so the sibling codec imports work.

1. Zip the `tool/` folder.
2. Blender > Edit > Preferences > Add-ons > Install… > pick the zip > enable **UV Region Exporter**.
3. The panel appears in the 3D viewport sidebar (`N`) under the **UV Regions** tab.

## Workflow

1. Select the mesh. It must have an **active UV map** (regions are stored as UV triangles).
2. In the **UV Regions** panel, **＋** to add a region; rename it (the name is what the runtime
   keys on — match the region names the game expects).
3. Enter **Edit Mode**, select the faces for that region, click **Assign Selected Faces**.
   - Assignment is per face; each face belongs to at most one region (last assign wins).
   - **Select Region Faces** reselects a region's faces to check coverage.
4. **Export UV Regions** writes a `.uvr.txt` (raw base64) and also copies it to the clipboard.

Face → region membership is stored on the mesh as an integer face attribute (`uv_region_id`),
so it saves with the .blend and survives across sessions.

## Blob format (v1)

Little-endian. Authored and consumed only through `uv_region_codec.py` — treat this table as
documentation, not a second implementation.

```
magic        4s   "UVRG"
version      u8   1
flags        u8   0 (reserved)
regionCount  u16
uvCount      u32
uvs          uvCount * (u16 u, u16 v)      quantized: round(clamp(uv, 0, 1) * 65535)
regions      regionCount * {
    nameLen  u16
    name     nameLen bytes utf-8
    triCount u32
    tris     triCount * (u32 a, u32 b, u32 c)   indices into uvs
}
```

UV points are deduplicated across all regions and quantized to u16 per axis (≈ sub-texel at 4K).
Quads and n-gons are fan-triangulated on export, so the runtime only ever sees triangles.

## Limitations (v1)

- UVs are clamped to `[0, 1]`; tiling / UDIM layouts aren't supported.
- One region per face. Overlapping regions in UV space are the runtime's problem to resolve
  (planned rule: last region wins), not the exporter's.
- Re-exports after re-unwrapping the mesh are required if the UVs change — the blob encodes UV
  positions, not just topology.

## Testing

```bash
python3 tool/tests/test_codec.py
```

The addon UI itself has to be exercised inside Blender (no `bpy` outside it).

"""UV Region Exporter — a Blender addon for authoring paintable regions on a mesh.

Artists assign faces to named regions in the viewport; export writes a base64 blob (see
``uv_region_codec``) that the Luau runtime decodes and rasterizes into per-region texture masks.

Install: zip this ``tool/`` folder and install the zip via Edit > Preferences > Add-ons > Install,
or point Blender's scripts path at it. The addon loads as a package so the sibling codec module
imports cleanly.
"""

bl_info = {
    "name": "UV Region Exporter",
    "author": "OutOfBears",
    "version": (0, 1, 0),
    "blender": (4, 0, 0),
    "location": "View3D > Sidebar > UV Regions",
    "description": "Assign faces to named regions and export them as a base64 UV-region blob.",
    "category": "Import-Export",
}

import bmesh
import bpy
from bpy.props import CollectionProperty, IntProperty, StringProperty
from bpy.types import Operator, Panel, PropertyGroup
from bpy_extras.io_utils import ExportHelper

from . import uv_region_codec

ATTR_NAME = "uv_region_id"


def _active_region(obj):
    idx = obj.uv_regions_active
    if 0 <= idx < len(obj.uv_regions):
        return obj.uv_regions[idx]
    return None


class UVRegionItem(PropertyGroup):
    name: StringProperty(name="Name", default="Region")
    region_id: IntProperty(name="ID", default=0)


class UVREGION_OT_add(Operator):
    bl_idname = "uvregion.add"
    bl_label = "Add Region"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        obj = context.object
        item = obj.uv_regions.add()
        item.region_id = obj.uv_regions_next_id
        item.name = "Region %d" % obj.uv_regions_next_id
        obj.uv_regions_next_id += 1
        obj.uv_regions_active = len(obj.uv_regions) - 1
        return {"FINISHED"}


class UVREGION_OT_remove(Operator):
    bl_idname = "uvregion.remove"
    bl_label = "Remove Region"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        obj = context.object
        idx = obj.uv_regions_active
        if 0 <= idx < len(obj.uv_regions):
            obj.uv_regions.remove(idx)
            obj.uv_regions_active = min(idx, len(obj.uv_regions) - 1)
        return {"FINISHED"}


class UVREGION_OT_assign(Operator):
    bl_idname = "uvregion.assign"
    bl_label = "Assign Selected Faces"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        obj = context.object
        region = _active_region(obj)
        if region is None:
            self.report({"WARNING"}, "No active region")
            return {"CANCELLED"}
        if obj.mode != "EDIT":
            self.report({"WARNING"}, "Enter Edit Mode to assign faces")
            return {"CANCELLED"}

        bm = bmesh.from_edit_mesh(obj.data)
        layer = bm.faces.layers.int.get(ATTR_NAME) or bm.faces.layers.int.new(ATTR_NAME)

        count = 0
        for face in bm.faces:
            if face.select:
                face[layer] = region.region_id
                count += 1

        bmesh.update_edit_mesh(obj.data)
        self.report({"INFO"}, "Assigned %d faces to %s" % (count, region.name))
        return {"FINISHED"}


class UVREGION_OT_select(Operator):
    bl_idname = "uvregion.select"
    bl_label = "Select Region Faces"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        obj = context.object
        region = _active_region(obj)
        if region is None:
            return {"CANCELLED"}
        if obj.mode != "EDIT":
            self.report({"WARNING"}, "Enter Edit Mode to select faces")
            return {"CANCELLED"}

        bm = bmesh.from_edit_mesh(obj.data)
        layer = bm.faces.layers.int.get(ATTR_NAME)
        if layer is None:
            return {"CANCELLED"}

        for face in bm.faces:
            face.select_set(face[layer] == region.region_id)

        bm.select_flush(True)
        bmesh.update_edit_mesh(obj.data)
        return {"FINISHED"}


def _gather_regions(obj):
    mesh = obj.data
    if not mesh.uv_layers.active:
        raise RuntimeError("Mesh has no active UV map")

    # Read through bmesh so this works in both Edit and Object mode -- the plain mesh.* proxies
    # (attributes, loop_triangles) are empty while the mesh is open in Edit Mode.
    in_edit = obj.mode == "EDIT"
    if in_edit:
        bm = bmesh.from_edit_mesh(mesh)
    else:
        bm = bmesh.new()
        bm.from_mesh(mesh)

    try:
        uv_layer = bm.loops.layers.uv.active
        region_layer = bm.faces.layers.int.get(ATTR_NAME)

        buckets = {region.region_id: [] for region in obj.uv_regions}
        if uv_layer is not None and region_layer is not None:
            for face in bm.faces:
                bucket = buckets.get(face[region_layer])
                if bucket is None:
                    continue
                uvs = [tuple(loop[uv_layer].uv) for loop in face.loops]
                for i in range(1, len(uvs) - 1):
                    bucket.append((uvs[0], uvs[i], uvs[i + 1]))
    finally:
        if not in_edit:
            bm.free()

    return [
        {"name": region.name, "triangles": buckets[region.region_id]}
        for region in obj.uv_regions
        if buckets[region.region_id]
    ]


class UVREGION_OT_export(Operator, ExportHelper):
    bl_idname = "uvregion.export"
    bl_label = "Export UV Regions"
    bl_options = {"REGISTER"}

    filename_ext = ".uvr.txt"
    filter_glob: StringProperty(default="*.uvr.txt", options={"HIDDEN"})

    def execute(self, context):
        obj = context.object
        try:
            regions = _gather_regions(obj)
        except RuntimeError as err:
            self.report({"ERROR"}, str(err))
            return {"CANCELLED"}

        if not regions:
            self.report({"ERROR"}, "No faces assigned to any region")
            return {"CANCELLED"}

        blob = uv_region_codec.encode_b64(regions)
        with open(self.filepath, "w", encoding="ascii") as handle:
            handle.write(blob)
        context.window_manager.clipboard = blob

        triangles = sum(len(region["triangles"]) for region in regions)
        self.report(
            {"INFO"},
            "Exported %d regions, %d triangles (also copied to clipboard)" % (len(regions), triangles),
        )
        return {"FINISHED"}


class UVREGION_PT_panel(Panel):
    bl_label = "UV Regions"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "UV Regions"

    @classmethod
    def poll(cls, context):
        return context.object is not None and context.object.type == "MESH"

    def draw(self, context):
        layout = self.layout
        obj = context.object

        row = layout.row()
        row.template_list("UI_UL_list", "uv_regions", obj, "uv_regions", obj, "uv_regions_active", rows=4)
        col = row.column(align=True)
        col.operator("uvregion.add", icon="ADD", text="")
        col.operator("uvregion.remove", icon="REMOVE", text="")

        region = _active_region(obj)
        if region is not None:
            layout.prop(region, "name")

        col = layout.column(align=True)
        col.operator("uvregion.assign", icon="FACESEL")
        col.operator("uvregion.select", icon="RESTRICT_SELECT_OFF")

        layout.operator("uvregion.export", icon="EXPORT")


_CLASSES = (
    UVRegionItem,
    UVREGION_OT_add,
    UVREGION_OT_remove,
    UVREGION_OT_assign,
    UVREGION_OT_select,
    UVREGION_OT_export,
    UVREGION_PT_panel,
)


def register():
    for cls in _CLASSES:
        bpy.utils.register_class(cls)
    bpy.types.Object.uv_regions = CollectionProperty(type=UVRegionItem)
    bpy.types.Object.uv_regions_active = IntProperty(default=0)
    bpy.types.Object.uv_regions_next_id = IntProperty(default=1)


def unregister():
    del bpy.types.Object.uv_regions_next_id
    del bpy.types.Object.uv_regions_active
    del bpy.types.Object.uv_regions
    for cls in reversed(_CLASSES):
        bpy.utils.unregister_class(cls)

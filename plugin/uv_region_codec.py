"""Encode/decode the UV-region blob shared by the Blender exporter and the Luau runtime.

Pure Python, no ``bpy`` — so it can be unit-tested outside Blender and reused by the addon.

A region's paintable footprint is stored as UV-space triangles ("loops"): a deduplicated table
of quantized UV points plus, per region, the triangles covering it as indices into that table.
The runtime rasterizes those triangles into a per-texel region mask.

Binary layout (little-endian):

    magic        4s   b"UVRG"
    version      u8   1
    flags        u8   0 (reserved)
    regionCount  u16
    uvCount      u32
    uvs          uvCount * (u16 u, u16 v)      -- quantized: round(clamp(uv,0,1) * 65535)
    regions      regionCount * {
        nameLen  u16
        name     nameLen bytes utf-8
        triCount u32
        tris     triCount * (u32 a, u32 b, u32 c)   -- indices into uvs
    }

UVs are clamped to [0, 1]; tiling / UDIM layouts are out of scope.
"""

import base64
import struct

MAGIC = b"UVRG"
VERSION = 1

_HEADER = struct.Struct("<4sBBH")
_U32 = struct.Struct("<I")
_UV = struct.Struct("<HH")
_U16 = struct.Struct("<H")
_TRI = struct.Struct("<III")


def _quantize(value):
    if value <= 0.0:
        return 0
    if value >= 1.0:
        return 65535
    return int(round(value * 65535.0))


def _dequantize(value):
    return value / 65535.0


def encode(regions):
    """Pack regions into the blob bytes.

    ``regions`` is an iterable of ``{"name": str, "triangles": [(uv, uv, uv), ...]}`` where each
    ``uv`` is a ``(u, v)`` float pair.
    """
    uv_index = {}
    uv_table = []

    def intern(uv):
        key = (_quantize(uv[0]), _quantize(uv[1]))
        idx = uv_index.get(key)
        if idx is None:
            idx = len(uv_table)
            uv_index[key] = idx
            uv_table.append(key)
        return idx

    region_chunks = []
    for region in regions:
        name_bytes = region["name"].encode("utf-8")
        if len(name_bytes) > 0xFFFF:
            raise ValueError("region name too long: %r" % region["name"])

        triangles = region["triangles"]
        parts = [_U16.pack(len(name_bytes)), name_bytes, _U32.pack(len(triangles))]
        for tri in triangles:
            parts.append(_TRI.pack(intern(tri[0]), intern(tri[1]), intern(tri[2])))
        region_chunks.append(b"".join(parts))

    out = [_HEADER.pack(MAGIC, VERSION, 0, len(region_chunks)), _U32.pack(len(uv_table))]
    for qu, qv in uv_table:
        out.append(_UV.pack(qu, qv))
    out.extend(region_chunks)

    return b"".join(out)


def encode_b64(regions):
    return base64.b64encode(encode(regions)).decode("ascii")


def decode(data):
    """Inverse of :func:`encode`. UVs come back dequantized, so expect quantization error."""
    magic, version, _flags, region_count = _HEADER.unpack_from(data, 0)
    if magic != MAGIC:
        raise ValueError("bad magic: %r" % magic)
    if version != VERSION:
        raise ValueError("unsupported version: %d" % version)

    offset = _HEADER.size
    (uv_count,) = _U32.unpack_from(data, offset)
    offset += _U32.size

    uvs = []
    for _ in range(uv_count):
        qu, qv = _UV.unpack_from(data, offset)
        offset += _UV.size
        uvs.append((_dequantize(qu), _dequantize(qv)))

    regions = []
    for _ in range(region_count):
        (name_len,) = _U16.unpack_from(data, offset)
        offset += _U16.size
        name = data[offset:offset + name_len].decode("utf-8")
        offset += name_len
        (tri_count,) = _U32.unpack_from(data, offset)
        offset += _U32.size

        triangles = []
        for _ in range(tri_count):
            a, b, c = _TRI.unpack_from(data, offset)
            offset += _TRI.size
            triangles.append((uvs[a], uvs[b], uvs[c]))
        regions.append({"name": name, "triangles": triangles})

    return regions


def decode_b64(blob):
    return decode(base64.b64decode(blob))

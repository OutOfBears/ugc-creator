"""Round-trip test for uv_region_codec. Run with plain python3, no Blender needed:

    python3 tool/tests/test_codec.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import uv_region_codec as codec

_TOL = 2.0 / 65535.0


def _approx(a, b):
    return abs(a - b) <= _TOL


def _assert_regions_match(expected, actual):
    assert len(actual) == len(expected), "region count %d != %d" % (len(actual), len(expected))
    for want, got in zip(expected, actual):
        assert want["name"] == got["name"], (want["name"], got["name"])
        assert len(want["triangles"]) == len(got["triangles"]), want["name"]
        for tri_want, tri_got in zip(want["triangles"], got["triangles"]):
            for (uw, vw), (ug, vg) in zip(tri_want, tri_got):
                assert _approx(uw, ug) and _approx(vw, vg), (tri_want, tri_got)


def test_roundtrip():
    regions = [
        {
            "name": "Hair",
            "triangles": [
                ((0.0, 0.0), (1.0, 0.0), (1.0, 1.0)),
                ((0.0, 0.0), (1.0, 1.0), (0.0, 1.0)),
            ],
        },
        {
            "name": "Eyes",
            "triangles": [((0.25, 0.25), (0.5, 0.25), (0.5, 0.5))],
        },
        {
            "name": "Museau écran",  # non-ascii name must survive utf-8
            "triangles": [((0.1, 0.2), (0.3, 0.2), (0.3, 0.4))],
        },
    ]

    blob = codec.encode_b64(regions)
    _assert_regions_match(regions, codec.decode_b64(blob))

    raw = codec.encode(regions)
    # 4 distinct corners across Hair's 2 tris + 3 + 3 = 10 unique points, not 3*4=12.
    assert raw[0:4] == codec.MAGIC
    print("blob bytes: %d, b64 chars: %d" % (len(raw), len(blob)))


def test_clamps_out_of_range():
    regions = [{"name": "R", "triangles": [((-0.5, 1.5), (2.0, 0.0), (0.0, 0.0))]}]
    got = codec.decode_b64(codec.encode_b64(regions))
    (u0, v0), (u1, _), _ = got[0]["triangles"][0]
    assert _approx(u0, 0.0) and _approx(v0, 1.0) and _approx(u1, 1.0)


def test_empty_region_list():
    assert codec.decode_b64(codec.encode_b64([])) == []


if __name__ == "__main__":
    test_roundtrip()
    test_clamps_out_of_range()
    test_empty_region_list()
    print("OK: all codec tests passed")

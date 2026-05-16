"""
Smoke-test mirror of lib/features/export_import/data/gpx_exporter.dart.

Bukan port 1:1 — tujuannya hanya memastikan logika & struktur XML
yang dibangun valid (well-formed, root tidak self-closing, ada
metadata, ada trk per haul, dst). Kalau hasil di sini lulus assert,
implementasi Dart yang punya logika identik juga akan lulus.

This script is a developer aid only and is not shipped with the app.
"""
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from xml.dom import minidom


GPX_NS = "http://www.topografix.com/GPX/1/1"
XSI_NS = "http://www.w3.org/2001/XMLSchema-instance"
LSEA_NS = "https://langgengsea.id/gpx/extensions/v1"


def _root():
    return ET.Element("gpx", attrib={
        "version": "1.1",
        "creator": "Langgeng Sea",
        "xmlns": GPX_NS,
        "xmlns:xsi": XSI_NS,
        "xmlns:lsea": LSEA_NS,
        "xsi:schemaLocation": f"{GPX_NS} http://www.topografix.com/GPX/1/1/gpx.xsd",
    })


def _metadata(root, *, title, description=None, bounds=None, trip_ext=None):
    meta = ET.SubElement(root, "metadata")
    ET.SubElement(meta, "name").text = title
    if description:
        ET.SubElement(meta, "desc").text = description
    author = ET.SubElement(meta, "author")
    ET.SubElement(author, "name").text = "Langgeng Sea"
    link = ET.SubElement(author, "link", attrib={"href": "https://langgengsea.id"})
    ET.SubElement(link, "text").text = "Langgeng Sea"
    ET.SubElement(meta, "time").text = datetime.now(timezone.utc).isoformat()
    if bounds is not None:
        ET.SubElement(meta, "bounds", attrib={
            "minlat": str(bounds[0]), "minlon": str(bounds[1]),
            "maxlat": str(bounds[2]), "maxlon": str(bounds[3]),
        })
    if trip_ext is not None:
        exts = ET.SubElement(meta, "extensions")
        trip_ext(exts)
    return meta


def _trk(root, haul, points):
    trk = ET.SubElement(root, "trk")
    ET.SubElement(trk, "name").text = haul.get("name") or f"Tarikan #{haul['orderIndex']}"
    ET.SubElement(trk, "desc").text = (
        f"Tarikan #{haul['orderIndex']} · "
        f"lebar trawl {haul.get('trawlWidthMeters', 20):.1f} m"
    )
    ET.SubElement(trk, "type").text = "fishing-haul"
    exts = ET.SubElement(trk, "extensions")
    lsea_haul = ET.SubElement(
        exts, "lsea:haul",
        attrib={"id": haul["id"], "orderIndex": str(haul["orderIndex"]),
                "status": haul.get("status", "completed")},
    )
    ET.SubElement(lsea_haul, "lsea:distanceMeters").text = f"{haul.get('distanceMeters', 0):.2f}"

    seg = ET.SubElement(trk, "trkseg")
    for p in points:
        pt = ET.SubElement(seg, "trkpt", attrib={
            "lat": str(p["lat"]), "lon": str(p["lon"])
        })
        ET.SubElement(pt, "time").text = p["ts"]
        if "speed" in p:
            ET.SubElement(pt, "speed").text = f"{p['speed']:.2f}"
    return trk


def _wpt(root, marker):
    wpt = ET.SubElement(root, "wpt", attrib={
        "lat": str(marker["lat"]), "lon": str(marker["lon"]),
    })
    ET.SubElement(wpt, "time").text = marker["createdAt"]
    ET.SubElement(wpt, "name").text = marker["name"]
    if marker.get("notes"):
        ET.SubElement(wpt, "desc").text = marker["notes"]
    ET.SubElement(wpt, "sym").text = "Skull and Crossbones"
    ET.SubElement(wpt, "type").text = "Karang/Bahaya"
    exts = ET.SubElement(wpt, "extensions")
    ET.SubElement(exts, "lsea:marker",
                  attrib={"id": marker["id"], "category": marker["category"]})
    return wpt


def export_trip(trip, hauls, points_by_haul, markers=None):
    markers = markers or []
    root = _root()
    _metadata(
        root,
        title=trip.get("name") or "Trip Langgeng Sea",
        description=f"{len(hauls)} tarikan",
        bounds=None,
        trip_ext=lambda exts: ET.SubElement(
            exts, "lsea:trip",
            attrib={"id": trip["id"], "status": trip.get("status", "completed")},
        ),
    )
    for marker in markers:
        _wpt(root, marker)
    for haul in hauls:
        _trk(root, haul, points_by_haul.get(haul["id"], []))
    raw = ET.tostring(root, encoding="utf-8").decode()
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + raw


def pretty(xml_str):
    return minidom.parseString(xml_str).toprettyxml(indent="  ")


# ---------- assertions / smoke-tests ----------

# 1) Trip kosong (skenario user) tidak boleh menghasilkan gpx self-closing
empty = export_trip(
    trip={"id": "trip-1", "name": "Trip Kosong"},
    hauls=[],
    points_by_haul={},
)
assert "</gpx>" in empty, "root must NOT be self-closing"
assert "<metadata>" in empty
assert "<trk" not in empty
print("[1] empty trip OK — produces metadata, no trk:")
print(pretty(empty)[:700], "...\n")

# 2) Trip dengan dua haul
two = export_trip(
    trip={"id": "trip-1", "name": "Trip Siang"},
    hauls=[
        {"id": "h1", "orderIndex": 1, "name": "Haul 1",
         "distanceMeters": 1000, "trawlWidthMeters": 20},
        {"id": "h2", "orderIndex": 2, "name": "Haul 2",
         "distanceMeters": 500, "trawlWidthMeters": 20},
    ],
    points_by_haul={
        "h1": [{"lat": -6.88, "lon": 110.41, "ts": "2024-06-15T06:00:00Z", "speed": 2.5}],
        "h2": [],
    },
)
assert two.count("<trk>") == 2
assert "<name>Haul 1</name>" in two
print("[2] trip with two hauls OK — 2 <trk>, h2 empty stub still emitted")

# 3) Markers as <wpt>
wpt_test = export_trip(
    trip={"id": "trip-1", "name": "Trip Tengah"},
    hauls=[],
    points_by_haul={},
    markers=[{
        "id": "m-1", "name": "Karang Hiu", "category": "hazard",
        "lat": -6.9, "lon": 110.5, "notes": "Hindari saat air pasang",
        "createdAt": "2024-06-01T00:00:00Z",
    }],
)
assert '<wpt lat="-6.9" lon="110.5">' in wpt_test
assert '<lsea:marker id="m-1" category="hazard"' in wpt_test
print("[3] marker -> <wpt> with lsea:marker extension OK")

print("\nAll GPX-shape smoke tests passed.")

"""
Smoke-test mirror of lib/features/export_import/data/gpx_exporter.dart.

Bukan port 1:1 — tujuannya hanya memastikan logika & struktur XML
yang dibangun valid (well-formed, root tidak self-closing, ada
metadata, ada trk per haul, dst). Kalau hasil di sini lulus assert,
implementasi Dart yang punya logika identik juga akan lulus.

PR #27 menambah:
- <lsea:exporter> block (vesselName, ownerName, exportedAt,
  filterDescription)
- <lsea:summary> rolled-up totals
- <lsea:trip> per <trk> (parent trip metadata)
- <lsea:haul colorValue colorHex> (warna jalur)

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


def _metadata(root, *, title, description=None, bounds=None,
              exporter=None, summary=None, filter_description=None,
              author_name=None):
    meta = ET.SubElement(root, "metadata")
    ET.SubElement(meta, "name").text = title
    if description:
        ET.SubElement(meta, "desc").text = description
    author = ET.SubElement(meta, "author")
    ET.SubElement(author, "name").text = author_name or "Langgeng Sea"
    link = ET.SubElement(author, "link", attrib={"href": "https://langgengsea.id"})
    ET.SubElement(link, "text").text = "Langgeng Sea"
    ET.SubElement(meta, "time").text = datetime.now(timezone.utc).isoformat()
    if bounds is not None:
        ET.SubElement(meta, "bounds", attrib={
            "minlat": str(bounds[0]), "minlon": str(bounds[1]),
            "maxlat": str(bounds[2]), "maxlon": str(bounds[3]),
        })

    has_ext = exporter is not None or summary is not None or filter_description is not None
    if has_ext:
        exts = ET.SubElement(meta, "extensions")
        if exporter is not None:
            exporter_el = ET.SubElement(exts, "lsea:exporter")
            ET.SubElement(exporter_el, "lsea:vesselName").text = exporter["vesselName"]
            ET.SubElement(exporter_el, "lsea:ownerName").text = exporter["ownerName"]
            if exporter.get("homePort"):
                ET.SubElement(exporter_el, "lsea:homePort").text = exporter["homePort"]
            if exporter.get("trawlWidthMeters") is not None:
                ET.SubElement(exporter_el, "lsea:trawlWidthMeters").text = (
                    f"{exporter['trawlWidthMeters']:.2f}"
                )
            ET.SubElement(exporter_el, "lsea:exportedAt").text = (
                datetime.now(timezone.utc).isoformat()
            )
            if filter_description:
                ET.SubElement(exporter_el, "lsea:filterDescription").text = filter_description
        elif filter_description:
            placeholder = ET.SubElement(
                exts, "lsea:exporter", attrib={"hasUserProfile": "false"}
            )
            ET.SubElement(placeholder, "lsea:exportedAt").text = (
                datetime.now(timezone.utc).isoformat()
            )
            ET.SubElement(placeholder, "lsea:filterDescription").text = filter_description
        if summary is not None:
            ET.SubElement(exts, "lsea:summary", attrib={
                "tripCount": str(summary["tripCount"]),
                "haulCount": str(summary["haulCount"]),
                "markerCount": str(summary["markerCount"]),
                "totalDistanceMeters": f"{summary['totalDistanceMeters']:.2f}",
                "totalDurationSeconds": str(summary["totalDurationSeconds"]),
                "totalSweptAreaM2": f"{summary['totalSweptAreaM2']:.2f}",
            })
    return meta


def _trk(root, haul, points, *, parent_trip=None):
    trk = ET.SubElement(root, "trk")
    ET.SubElement(trk, "name").text = haul.get("name") or f"Tarikan #{haul['orderIndex']}"
    ET.SubElement(trk, "desc").text = (
        f"Tarikan #{haul['orderIndex']} · "
        f"lebar trawl {haul.get('trawlWidthMeters', 20):.1f} m"
    )
    ET.SubElement(trk, "type").text = "fishing-haul"

    exts = ET.SubElement(trk, "extensions")
    if parent_trip is not None:
        trip_attrs = {
            "id": parent_trip["id"],
            "status": parent_trip.get("status", "completed"),
        }
        if parent_trip.get("name"):
            trip_attrs["name"] = parent_trip["name"]
        ET.SubElement(exts, "lsea:trip", attrib=trip_attrs)

    haul_attrs = {
        "id": haul["id"],
        "orderIndex": str(haul["orderIndex"]),
        "status": haul.get("status", "completed"),
        "distanceMeters": f"{haul.get('distanceMeters', 0):.2f}",
    }
    if haul.get("colorValue") is not None:
        argb = haul["colorValue"] & 0xFFFFFFFF
        rgb = argb & 0xFFFFFF
        haul_attrs["colorValue"] = f"0x{argb:08X}"
        haul_attrs["colorHex"] = f"#{rgb:06X}"
    ET.SubElement(exts, "lsea:haul", attrib=haul_attrs)

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
                  attrib={
                      "id": marker["id"],
                      "category": marker["category"],
                      "categoryLabel": marker.get("categoryLabel", marker["category"]),
                  })
    return wpt


def export_filtered(*, trip_list, hauls_by_trip, points_by_haul,
                    markers=None, exporter=None, filter_description=None):
    """Mirror of `GpxExporter.exportFiltered`."""
    markers = markers or []

    haul_count = sum(len(hs) for hs in hauls_by_trip.values())
    distance_total = sum(
        h.get("distanceMeters", 0)
        for hs in hauls_by_trip.values() for h in hs
    )
    duration_total = sum(
        h.get("durationSeconds", 0)
        for hs in hauls_by_trip.values() for h in hs
    )
    swept_total = sum(
        h.get("sweptAreaM2", 0)
        for hs in hauls_by_trip.values() for h in hs
    )

    summary = {
        "tripCount": len(trip_list),
        "haulCount": haul_count,
        "markerCount": len(markers),
        "totalDistanceMeters": distance_total,
        "totalDurationSeconds": duration_total,
        "totalSweptAreaM2": swept_total,
    }

    root = _root()
    _metadata(
        root,
        title="Data Langgeng Sea (Lengkap)",
        description=f"{len(trip_list)} trip · {haul_count} tarikan",
        exporter=exporter,
        summary=summary,
        filter_description=filter_description,
        author_name=exporter["ownerName"] if exporter else None,
    )

    for marker in markers:
        _wpt(root, marker)

    for trip in trip_list:
        for haul in hauls_by_trip.get(trip["id"], []):
            _trk(
                root, haul,
                points_by_haul.get(haul["id"], []),
                parent_trip=trip,
            )

    raw = ET.tostring(root, encoding="utf-8").decode()
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + raw


def pretty(xml_str):
    return minidom.parseString(xml_str).toprettyxml(indent="  ")


# ---------- assertions / smoke-tests ----------

# 1) Filter zero-result tetap valid GPX, root tidak self-closing.
empty = export_filtered(
    trip_list=[],
    hauls_by_trip={},
    points_by_haul={},
    exporter={
        "vesselName": "KM Bahari", "ownerName": "Pak Budi",
        "homePort": "Pelabuhan Tanjung", "trawlWidthMeters": 20.0,
    },
    filter_description="Semua waktu · Semua kategori",
)
assert "</gpx>" in empty, "root must NOT be self-closing"
assert "<metadata>" in empty
assert "<trk" not in empty
assert "<lsea:exporter>" in empty, "exporter block must be present"
assert "<lsea:vesselName>KM Bahari</lsea:vesselName>" in empty
assert "<lsea:summary " in empty, "summary block must be present"
assert 'tripCount="0"' in empty
assert 'haulCount="0"' in empty
print("[1] empty filter OK — emits metadata + lsea:exporter + lsea:summary")

# 2) Trip dengan dua haul — <lsea:trip> harus muncul di setiap track.
two = export_filtered(
    trip_list=[{"id": "trip-1", "name": "Trip Siang"}],
    hauls_by_trip={
        "trip-1": [
            {"id": "h1", "orderIndex": 1, "name": "Haul 1",
             "distanceMeters": 1000, "durationSeconds": 3600,
             "sweptAreaM2": 20000, "trawlWidthMeters": 20,
             "colorValue": 0xFF4FC3F7},
            {"id": "h2", "orderIndex": 2, "name": "Haul 2",
             "distanceMeters": 500, "durationSeconds": 1800,
             "sweptAreaM2": 10000, "trawlWidthMeters": 20},
        ],
    },
    points_by_haul={
        "h1": [{"lat": -6.88, "lon": 110.41,
                "ts": "2024-06-15T06:00:00Z", "speed": 2.5}],
        "h2": [],
    },
    exporter={"vesselName": "KM Bahari", "ownerName": "Pak Budi",
              "trawlWidthMeters": 20.0},
    filter_description="Jalur saja · Trip Siang",
)
assert two.count("<trk>") == 2
assert "<name>Haul 1</name>" in two
# Parent trip extension on every track.
assert two.count('<lsea:trip ') == 2
assert 'id="trip-1"' in two
# Color encoding round-trip (0xFF4FC3F7 → colorValue + #4FC3F7).
assert 'colorValue="0xFF4FC3F7"' in two
assert 'colorHex="#4FC3F7"' in two
# Summary roll-up.
assert 'totalDistanceMeters="1500.00"' in two
assert 'totalDurationSeconds="5400"' in two
print("[2] trip+2 hauls OK — lsea:trip per track + color hex + summary roll-up")

# 3) Markers as <wpt> with categoryLabel for human-readable.
wpt_test = export_filtered(
    trip_list=[],
    hauls_by_trip={},
    points_by_haul={},
    markers=[{
        "id": "m-1", "name": "Karang Hiu", "category": "hazard",
        "categoryLabel": "Karang/Bahaya",
        "lat": -6.9, "lon": 110.5, "notes": "Hindari saat air pasang",
        "createdAt": "2024-06-01T00:00:00Z",
    }],
    exporter={"vesselName": "KM Bahari", "ownerName": "Pak Budi",
              "trawlWidthMeters": 20.0},
    filter_description="Penanda saja · Karang/Bahaya",
)
assert '<wpt lat="-6.9" lon="110.5">' in wpt_test
assert 'category="hazard"' in wpt_test
assert 'categoryLabel="Karang/Bahaya"' in wpt_test
assert 'markerCount="1"' in wpt_test
print("[3] marker -> <wpt> with category + categoryLabel + summary OK")

# 4) Tanpa user profile (placeholder lsea:exporter).
no_exporter = export_filtered(
    trip_list=[],
    hauls_by_trip={},
    points_by_haul={},
    exporter=None,
    filter_description="Anonymous",
)
assert '<lsea:exporter hasUserProfile="false">' in no_exporter
assert '<lsea:vesselName>' not in no_exporter, (
    "placeholder must NOT carry vessel data"
)
assert "<lsea:filterDescription>Anonymous</lsea:filterDescription>" in no_exporter
print("[4] null exporter -> placeholder lsea:exporter block (hasUserProfile=false) OK")

# 5) ParseAble XML.
ET.fromstring(empty)
ET.fromstring(two)
ET.fromstring(wpt_test)
ET.fromstring(no_exporter)
print("[5] all four files parse as well-formed XML")

print("\nAll PR #27 GPX-shape smoke tests passed.")

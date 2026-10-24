#!/usr/bin/env python3
"""Builds Resources/Companion/gels.json from the researched gel list.

    python3 TitanDeck/Tools/import_gels.py research.json

The research file is a JSON array with manufacturer, range, number, name,
category, transmission, transmissionDaylight, miredShift, hex, source and
description per filter (LEE, Rosco E-Colour+/Roscolux/Cinegel, GAM), taken
from the manufacturers' own published data. Swatch colours are the ones
LEE and Rosco show on their websites: approximate, and theirs.
"""
import json
import re
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "Resources" / "Companion" / "gels.json"


def rgb(hex_value):
    value = (hex_value or "#FFFFFF").lstrip("#")
    if len(value) == 3:
        value = "".join(c * 2 for c in value)
    return {"r": int(value[0:2], 16), "g": int(value[2:4], 16), "b": int(value[4:6], 16)}


def slug(text):
    return re.sub(r"[^A-Za-z0-9]+", "-", text).strip("-")


def main(source):
    research = json.loads(Path(source).read_text())
    seen = set()
    gels = []
    for item in research:
        gel_id = f"gel-{slug(item['manufacturer'])}-{slug(item.get('range') or '')}-{slug(item['number'])}"
        if gel_id in seen:
            continue
        seen.add(gel_id)
        gel = {
            "id": gel_id,
            "manufacturer": item["manufacturer"],
            "range": item.get("range"),
            "number": item["number"],
            "name": item["name"],
            "category": item.get("category"),
            "description": item.get("description"),
            "transmission": item.get("transmission") if item.get("transmission") is not None
            else item.get("transmissionFromSpectrum"),
            "transmissionDaylight": item.get("transmissionDaylight"),
            "miredShift": item.get("miredShift"),
            "swatchRgb": rgb(item.get("hex")),
            "source": item.get("source"),
        }
        gels.append({k: v for k, v in gel.items() if v is not None})
    order = {"Lee": 0, "Rosco": 1, "GAM": 2}
    gels.sort(key=lambda g: (order.get(g["manufacturer"], 9), g.get("range") or "", g["number"]))
    OUT.write_text(json.dumps(gels, indent=1, ensure_ascii=False) + "\n")
    print(f"Wrote {len(gels)} gels to {OUT}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])

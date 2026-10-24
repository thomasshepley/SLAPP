#!/usr/bin/env python3
"""Tags each DMX channel in Resources/Companion/fixtures.json with the pixel
cell it drives, so the app can draw pixel maps and say which cell does what.

Researchers labelled cells in each maker's own words: "Cell 3 Red",
"LE2 Dimmer", "Zone 4 Level", "P5 Red", "Red [6]", "Dimmer zone 2",
"Red LED 12", "Aura pixel 40 Red". This reads the number out and writes
"cell" (1-based, in DMX order) on the channel. Fixtures with more than one
set of pixels (MAC Aura PXL beam and aura, GLP JDC1 plate and beam, Robe
Spiider zones and pixels) also get "cellGroup".

Run it after merge_fixture_modes.py:

    python3 Tools/tag_pixel_cells.py [--write]
"""
import argparse
import collections
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "Resources" / "Companion" / "fixtures.json"

# (pattern, group) in order; the first match wins. "n" is the cell number,
# "g" (when present) names the pixel set.
RULES = [
    (r"^(?P<g>Beam|Aura) (?:pixel|Pixel) (?P<n>\d+)\b", None),
    (r"^(?P<g>Plate Background|Plate|Beam) Pixel (?P<n>\d+)\b", None),
    (r"^(?:Red|Green|Blue|White|Amber|Lime|Cyan|Dimmer|Intensity)[^-]*- (?P<g>zone) (?P<n>\d+)$", None),
    (r"^(?:Red|Green|Blue|White|Amber|Lime|Cyan|Dimmer|Intensity)\b.* (?P<g>pixel) (?P<n>\d+)$", None),
    (r"^(?:Cell|Zone|Engine|Pixel|Segment|Set|Section) (?P<n>\d+)\b", None),
    (r"^LE(?P<n>\d+)\b", None),
    (r"^P(?P<n>\d+) ", None),
    (r"\[(?P<n>\d+)\]$", None),
    (r"\b(?:zone|LED) (?P<n>\d+)$", None),
    (r"^(?:Dimmer|Red|Green|Blue|White|Strobe) (?P<n>\d+)$", None),
]
COMPILED = [re.compile(p) for p, _ in RULES]
# Labels that look numbered but aren't pixels.
NOT_CELLS = re.compile(r"Gel|Mode \d|Effect|FX|Mem|parameter|Parameter|slot|Colour \d|Color \d|Preset|Favou?rite")
# The Robe Spiider's zone labels say which LED ring they colour, not a pixel.
GROUP_NAMES = {"zone": "Zone", "pixel": "Pixel", "Beam": "Beam", "Aura": "Aura",
               "Plate": "Plate", "Plate Background": "Plate background"}


# GLP X4 Bar Dual Pixel modes drive lenses in pairs: "Set 3&4 Red" is cell 2.
PAIR = re.compile(r"^Set (?P<a>\d+)&(?P<b>\d+)\b")
# GLP X4 Bar Normal modes number colour layers ("Set 2 Pattern Select"), not pixels.
LAYER_MODE = re.compile(r"^Set \d+ (?:Colour \(Fixed|Pattern)")


def cell_of(label):
    pair = PAIR.search(label)
    if pair:
        return (int(pair.group("a")) + 1) // 2, None
    if NOT_CELLS.search(label):
        return None, None
    for rule in COMPILED:
        match = rule.search(label)
        if match:
            group = match.groupdict().get("g")
            return int(match.group("n")), GROUP_NAMES.get(group, group) if group else None
    return None, None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    fixtures = json.loads(FIXTURES.read_text())
    summary = collections.Counter()
    for fixture in fixtures:
        for mode in fixture["modes"]:
            tagged = []
            layers = any(LAYER_MODE.search(channel["label"]) for channel in mode["channels"])
            for channel in mode["channels"]:
                channel.pop("cell", None)
                channel.pop("cellGroup", None)
                cell, group = (None, None) if layers else cell_of(channel["label"])
                if cell:
                    channel["cell"] = cell
                    if group:
                        channel["cellGroup"] = group
                    tagged.append((group, cell))
            groups = collections.defaultdict(set)
            for group, cell in tagged:
                groups[group].add(cell)
            # One numbered channel on its own isn't a pixel mode.
            if not any(len(cells) > 1 or mode.get("repeatCells") for cells in groups.values()):
                for channel in mode["channels"]:
                    channel.pop("cell", None)
                    channel.pop("cellGroup", None)
                continue
            summary[fixture["id"]] += 1
    for fid, count in sorted(summary.items()):
        print(f"{fid}: {count} pixel modes")
    print(f"{len(summary)} fixtures with pixel modes")
    if args.write:
        lines = (json.dumps(f, ensure_ascii=False, separators=(",", ":")) for f in fixtures)
        FIXTURES.write_text("[\n" + ",\n".join(lines) + "\n]\n")
        print("wrote", FIXTURES.relative_to(ROOT))


if __name__ == "__main__":
    main()

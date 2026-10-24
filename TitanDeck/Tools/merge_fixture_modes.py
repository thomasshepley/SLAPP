#!/usr/bin/env python3
"""Merge researched DMX modes (and new fixtures) into Resources/Companion/fixtures.json.

Each research file looks like:
  {"fixtures": {"<fixture id>": {"source": "<url>", "modes": [...]}},
   "newFixtures": [<full fixture>, ...]}

A fixture's researched modes replace its old ones. Every mode is checked:
unique names, known attributes, no overlapping slots, and a footprint that
adds up (16-bit = 2 slots, pixel cells repeated with repeatCells/cellSize).
Anything that fails is reported and that fixture keeps its old modes.

  python3 Tools/merge_fixture_modes.py research/*.json [--new extra-fixtures.json] [--drop id] [--write]
"""
import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "Resources" / "Companion" / "fixtures.json"

ATTRIBUTES = {
    "intensity", "red", "green", "blue", "white", "amber", "lime", "cyan", "magenta", "yellow",
    "cct", "tint", "pan", "tilt", "zoom", "focus", "gobo", "colourWheel", "shutter", "control", "other",
}
# Words researchers reach for that mean one of ours.
ALIASES = {
    "dimmer": "intensity", "strobe": "shutter", "colorwheel": "colourWheel", "colourwheel": "colourWheel",
    "color": "colourWheel", "uv": "other", "indigo": "other", "fx": "control", "effect": "control",
    "effects": "control", "macro": "control", "crossfade": "control", "gm": "tint", "hue": "other",
    "saturation": "other", "fan": "control", "iris": "zoom", "prism": "gobo", "frost": "focus",
}
MODE_KEYS = ["name", "number", "summary", "channelCount", "channels", "powerW", "repeatCells", "cellSize", "cellStart"]


def clean_text(value):
    """Ordinary hyphens and quotes, single spaces."""
    if not isinstance(value, str):
        return value
    value = value.replace("\u2014", "-").replace("\u2013", "-").replace("\u2212", "-")
    value = value.replace("\u2018", "'").replace("\u2019", "'").replace("\u201c", '"').replace("\u201d", '"')
    value = value.replace("\u00b0", " deg").replace("\u00d7", "x").replace("\u00b5", "u")
    return re.sub(r"\s+", " ", value).strip()


def clean_attribute(raw, problems, where):
    if raw in ATTRIBUTES:
        return raw
    key = str(raw).replace("_", "").replace(" ", "").lower()
    for name in ATTRIBUTES:
        if name.lower() == key:
            return name
    if key in ALIASES:
        return ALIASES[key]
    problems.append(f"{where}: unknown attribute {raw!r}, using other")
    return "other"


def cell_start(taken, end, cells, size, count):
    """Where cell 1 starts in a pixel mode that lists one cell. The other
    cells follow it, so the slots after cell 1 are free for (cells - 1) x size;
    channels after that (fan, strobe...) sit at their true offsets."""
    if not (isinstance(cells, int) and isinstance(size, int) and cells > 1 and size > 0):
        return None
    gap = (cells - 1) * size
    for start in range(0, end - size + 1):
        block = range(start, start + size)
        after = range(start + size, start + size + gap)
        if start + size + gap > count or not any(slot in taken for slot in block):
            continue
        if (start + size) in taken or (start + size - 1) not in taken:
            continue
        if any(slot in taken for slot in after):
            continue
        return start
    return None


def check_mode(mode, where, warnings):
    """Returns (cleaned mode, errors)."""
    errors = []
    out = {}
    name = clean_text(mode.get("name") or "")
    number = mode.get("number")
    number = clean_text(str(number)) if number not in (None, "") else None
    if number is not None:
        number = re.sub(r"^(mode|m)\s*", "", number, flags=re.I)
    summary = clean_text(mode.get("summary")) or None
    if not name:
        name = f"Mode {number} {summary}".strip() if number else (summary or "")
    if not name:
        errors.append(f"{where}: mode without a name")
    out["name"] = name
    if number:
        out["number"] = number
    if summary:
        out["summary"] = summary

    count = mode.get("channelCount")
    if not isinstance(count, int) or not 1 <= count <= 512:
        errors.append(f"{where} / {name}: channelCount {count!r}")
        return out, errors
    out["channelCount"] = count

    channels = []
    taken = {}
    for channel in mode.get("channels") or []:
        offset = channel.get("offset")
        resolution = channel.get("resolution", 8)
        if resolution in (1, 2, 3):
            resolution *= 8
        if not isinstance(offset, int) or offset < 0 or resolution not in (8, 16, 24):
            errors.append(f"{where} / {name}: bad channel {channel}")
            continue
        label = clean_text(channel.get("label") or "") or "-"
        cleaned = {
            "offset": offset,
            "resolution": resolution,
            "attribute": clean_attribute(channel.get("attribute", "other"), warnings, f"{where} / {name} / {label}"),
            "label": label,
        }
        ranges = []
        top = (1 << resolution) - 1
        for r in channel.get("ranges") or []:
            lo, hi = r.get("from"), r.get("to")
            if isinstance(lo, int) and isinstance(hi, int) and 0 <= lo <= hi <= top:
                ranges.append({"from": lo, "to": hi, "label": clean_text(r.get("label") or "")})
            else:
                warnings.append(f"{where} / {name} / {label}: dropped range {r}")
        if ranges:
            cleaned["ranges"] = ranges
        for slot in range(offset, offset + resolution // 8):
            if slot in taken:
                errors.append(f"{where} / {name}: slot {slot + 1} used by {taken[slot]!r} and {label!r}")
            taken[slot] = label
        channels.append(cleaned)
    if not channels:
        errors.append(f"{where} / {name}: no channels")
    channels.sort(key=lambda c: c["offset"])
    out["channels"] = channels

    if isinstance(mode.get("powerW"), (int, float)):
        out["powerW"] = mode["powerW"]

    end = max((c["offset"] + c["resolution"] // 8 for c in channels), default=0)
    cells, size = mode.get("repeatCells"), mode.get("cellSize")
    if cells is not None or size is not None:
        start = cell_start(taken, end, cells, size, count)
        if start is None:
            errors.append(f"{where} / {name}: {cells!r} cells of {size!r} don't fit a footprint of {count}")
        else:
            total = len(taken) + (cells - 1) * size
            if total < count:
                warnings.append(f"{where} / {name}: {count - total} of {count} slots undescribed")
            out["repeatCells"] = cells
            out["cellSize"] = size
            out["cellStart"] = start
    elif end > count:
        errors.append(f"{where} / {name}: channels reach slot {end}, footprint {count}")
    elif len(taken) < count:
        gap = count - len(taken)
        warnings.append(f"{where} / {name}: {gap} of {count} slots undescribed")
    return {k: out[k] for k in MODE_KEYS if k in out}, errors


def check_modes(modes, where, warnings):
    cleaned, errors, names = [], [], set()
    for mode in modes:
        good, problems = check_mode(mode, where, warnings)
        errors += problems
        if good.get("name") in names:
            # Same name twice (two footprints of one personality): keep both, told apart.
            good["name"] = f"{good['name']} ({good.get('channelCount')} ch)"
            if good["name"] in names:
                errors.append(f"{where}: duplicate mode name {good['name']!r}")
        names.add(good.get("name"))
        cleaned.append(good)
    return cleaned, errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("research", nargs="+", type=pathlib.Path)
    parser.add_argument("--new", type=pathlib.Path, action="append", default=[],
                        help="a JSON array of extra fixtures to add")
    parser.add_argument("--drop", action="append", default=[],
                        help="a fixture id to remove (no such product, say)")
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    fixtures = [f for f in json.loads(FIXTURES.read_text()) if f["id"] not in args.drop]
    by_id = {f["id"]: f for f in fixtures}
    warnings, failures = [], []
    replaced = added = 0

    extra = []
    for path in args.new:
        extra += json.loads(path.read_text())
    research = []
    for path in args.research:
        data = json.loads(path.read_text())
        research.append((path.name, data))
        extra += data.get("newFixtures") or []

    for fixture in extra:
        fid = fixture.get("id")
        if not fid or fid in by_id:
            warnings.append(f"new fixture {fid!r} skipped (missing id or already there)")
            continue
        modes, errors = check_modes(fixture.get("modes") or [], fid, warnings)
        if errors or not modes:
            failures += errors or [f"{fid}: no modes"]
            continue
        fixture = {k: clean_text(v) if isinstance(v, str) else v for k, v in fixture.items()}
        fixture["modes"] = modes
        fixture.setdefault("photometry", {"*": {}})
        for entry in fixture["photometry"].values():
            entry.setdefault("dimmingCurve", {"type": "linear"})
        fixtures.append(fixture)
        by_id[fid] = fixture
        added += 1

    for name, data in research:
        for fid, entry in (data.get("fixtures") or {}).items():
            fixture = by_id.get(fid)
            if fixture is None:
                warnings.append(f"{name}: unknown fixture {fid}")
                continue
            modes, errors = check_modes(entry.get("modes") or [], fid, warnings)
            if errors or not modes:
                failures += errors or [f"{fid}: no modes"]
                continue
            old_power = next((m.get("powerW") for m in fixture["modes"] if m.get("powerW")), None)
            for mode in modes:
                if "powerW" not in mode and old_power:
                    mode["powerW"] = old_power
            fixture["modes"] = [{k: m[k] for k in MODE_KEYS if k in m} for m in modes]
            if entry.get("source"):
                # Keep where the chart came from next to the fixture's other sources.
                source = fixture.get("source")
                fixture["source"] = source if isinstance(source, dict) else {}
                fixture["source"]["dmx"] = entry["source"]
            replaced += 1

    print(f"{len(fixtures)} fixtures: {replaced} with researched modes, {added} new")
    print(f"{sum(len(f['modes']) for f in fixtures)} modes in all")
    for line in warnings:
        print("warn:", line)
    for line in failures:
        print("FAIL:", line)
    if args.write:
        # One fixture per line: a third the size of indented JSON, still diffable.
        lines = (json.dumps(f, ensure_ascii=False, separators=(",", ":")) for f in fixtures)
        FIXTURES.write_text("[\n" + ",\n".join(lines) + "\n]\n")
        print("wrote", FIXTURES.relative_to(ROOT))
    return 1 if failures and not args.write else 0


if __name__ == "__main__":
    sys.exit(main())

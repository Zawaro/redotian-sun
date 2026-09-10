"""Set ArtData.is_remappable from the original game's art.ini Remapable flag.

art.ini is the source of truth for which objects remap to their owner's side
color. Each entity .tres links (via `legacy_id`) to an art.ini section and (via
`art_data`) to the ArtData .tres that renders it. This tool mirrors
`Remapable=yes` onto that ArtData and drops any authored minimap `color`, which
is redundant for remappable entities (they always take the owner's side color).

Usage:
    python tools/set_remapable_from_art_ini.py [--check]

--check reports drift without writing (exit 1 when changes are needed).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ART_INI = Path("references/art.ini")
ENTITIES_GLOB = "games/ts/entities/**/*.tres"

SECTION_RE = re.compile(r"^\[(.+?)\]$")
REMAPPABLE_RE = re.compile(r"^Remapable\s*=\s*(yes|no)\s*$", re.IGNORECASE)
LEGACY_ID_RE = re.compile(r'^legacy_id\s*=\s*"([^"]*)"', re.MULTILINE)
ART_REF_RE = re.compile(r'art_data\s*=\s*ExtResource\("([^"]+)"\)')
EXT_RES_RE = re.compile(r'\[ext_resource\b[^\]]*?path="([^"]+)"[^\]]*?id="([^"]+)"\]')


def remappable_sections() -> dict[str, bool]:
    result: dict[str, bool] = {}
    current: str | None = None
    for raw in ART_INI.read_text(encoding="latin-1").splitlines():
        line = raw.strip()
        section = SECTION_RE.match(line)
        if section:
            current = section.group(1)
            continue
        match = REMAPPABLE_RE.match(line)
        if current and match:
            result[current] = match.group(1).lower() == "yes"
    return result


def resolve_art_path(entity_text: str) -> str | None:
    ref = ART_REF_RE.search(entity_text)
    if not ref:
        return None
    res_id = ref.group(1)
    for path, ext_id in EXT_RES_RE.findall(entity_text):
        if ext_id == res_id:
            return path
    return None


def target_art_paths(remap: dict[str, bool]) -> set[str]:
    paths: set[str] = set()
    for entity in Path(".").glob(ENTITIES_GLOB):
        text = entity.read_text(encoding="latin-1")
        legacy = LEGACY_ID_RE.search(text)
        if not legacy or remap.get(legacy.group(1)) is not True:
            continue
        art_path = resolve_art_path(text)
        if art_path:
            paths.add(art_path)
    return paths


def apply_remappable(art_path: str, check: bool) -> bool:
    """Return True when the file needs/gets a change."""
    file_path = Path(art_path.replace("res://", "", 1))
    text = file_path.read_text(encoding="latin-1")
    lines = text.splitlines()
    has_remap = any(re.match(r"^is_remappable\s*=", line) for line in lines)
    changed = False
    out: list[str] = []
    inserted = False
    for line in lines:
        if re.match(r"^color\s*=", line):
            changed = True
            continue
        if re.match(r"^is_remappable\s*=", line):
            if line.strip() != "is_remappable = true":
                changed = True
            out.append("is_remappable = true")
            inserted = True
            continue
        out.append(line)
        if not has_remap and not inserted and re.match(r'^id\s*=\s*"', line):
            out.append("is_remappable = true")
            inserted = True
            changed = True
    if not inserted:
        out.append("is_remappable = true")
        changed = True
    if changed and not check:
        file_path.write_text("\n".join(out) + "\n", encoding="latin-1")
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report drift, write nothing")
    args = parser.parse_args()

    if not ART_INI.exists():
        print(f"error: {ART_INI} not found (run from the repo root)")
        return 2

    remap = remappable_sections()
    paths = sorted(target_art_paths(remap))
    changed = [path for path in paths if apply_remappable(path, args.check)]
    verb = "would update" if args.check else "updated"
    print(f"{len(remap)} art.ini sections; {len(paths)} remappable entity arts; {verb} {len(changed)}")
    if args.check and changed:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

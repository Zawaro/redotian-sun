## Why

`EntityData.adjacent` is meant to cap the number of **empty cells** allowed between a new structure and existing friendly structures (Tiberian Sun `Adjacent=N` semantics, confirmed via ModEnc). `BuildingManager._is_adjacency_satisfied` instead accepts a Chebyshev **cell distance** of `<= adjacent`, and cell distance = gap + 1 — so every building with `adjacent = 2` (all 22 shipped structure `.tres` files) is capped at a 1-cell gap in live gameplay. Issue #345.

## What Changes

- Fix the off-by-one in `_is_adjacency_satisfied` (scripts/buildings/BuildingManager.gd): accept footprint-cell Chebyshev distance `<= adjacent + 1` (i.e. gap `<= adjacent`).
- Update the function's doc comment and `EntityData.adjacent`'s doc comment to state gap semantics.
- Add regression tests in `test/unit/test_building_manager.gd`: adjacent=1 with a 1-cell gap accepted, adjacent=2 with a 2-cell gap accepted, adjacent=2 with a 3-cell gap rejected. Existing tests (touching accepted, no-neighbor rejected, stats-less neighbor ignored) are unchanged and remain valid.
- Document the deliberate divergence from Tiberian Sun in the building-manager spec: this remake treats `adjacent <= 0` as "no requirement" (TS uses 0 = must-touch, negative = placement disabled). The construction yard data depends on `<= 0` meaning free placement.
- Add an `adjacent` entry to `GLOSSARY.md` with the divergence noted.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `building-manager`: The adjacency requirement changes from "occupied cell within Chebyshev distance `adjacent` of any footprint cell" to "at most `adjacent` empty cells between footprints (Chebyshev distance `adjacent + 1`)". The no-requirement scenario (`adjacent <= 0`) is unchanged but its deliberate divergence from TS semantics is documented.

## Impact

- **Code**: `scripts/buildings/BuildingManager.gd` (one comparison + doc comment), `scripts/data/EntityData.gd` (doc comment only).
- **Tests**: `test/unit/test_building_manager.gd` — 3 new cases, 0 modified.
- **Docs**: `GLOSSARY.md` (new term entry), `openspec/specs/building-manager/spec.md` (via this change's delta).
- **Data**: No `.tres` changes — all 22 files already use `adjacent = 2` and simply start behaving as authored. Backward compatible with existing scenes; no `.tscn` touched. Only consumers of `can_place` are `place_building` and the placement preview tint, both updated by the shared fix.
- **Engine**: No engine or dependency changes.

## Context

`BuildingManager._is_adjacency_satisfied` (scripts/buildings/BuildingManager.gd:124) enforces `EntityData.adjacent` by accepting a Chebyshev distance of `<= adjacent` between the nearest footprint cells of the new building and each friendly building. Cell distance counts the cells themselves; the empty-cell gap between footprints is `distance - 1`. So `adjacent = 2` caps the gap at 1. All 22 shipped structure `.tres` files use `adjacent = 2`, making the constraint visibly tighter than intended in gameplay.

Tiberian Sun reference (ModEnc, `Adjacent=` flag): `Adjacent=0` requires contact without gap, `Adjacent=1` allows at most a 1-cell gap, i.e. **gap <= Adjacent**. Issue #345's expected behavior matches this.

Current consumers of the check: `can_place` is called only by `place_building` (BuildingManager.gd:153) and the placement-preview validity tint (:303). Fixing the shared predicate updates both. `adjacent <= 0` means "no requirement" — the construction yard `.tres` omits the field and relies on that for free placement (MCV deploy path).

## Goals / Non-Goals

**Goals:**
- Match TS gap semantics: `adjacent = N` allows up to `N` empty cells between footprints (Chebyshev distance `<= N + 1`).
- Prove the fix with regression tests that fail on the current code for the right reason.
- Document the gap semantics and the deliberate `<= 0` divergence in the spec and glossary.

**Non-Goals:**
- TS-faithful `adjacent = 0` (must-touch) and negative (disabled) semantics — no walls or data need them; the construction yard depends on `<= 0` = free placement.
- TS's default `Adjacent=3` for unset buildings — relevant only for the future `.map`/rules importer (#227), parked there.
- A BaseNormal-style filter on which neighbors count — the remake counts every friendly StatsComponent building.
- Any preview/UI, `.tres`, or `.tscn` changes.

## Decisions

- **`distance <= required + 1`, not `gap = distance - 1 <= required`.** Identical result; the former is a one-token diff on the existing line. Chebyshev is retained: cells strictly between two cells along an 8-direction axis equal `distance - 1`, so gap semantics stay exact on diagonals and corner-touch (distance 1) remains gap 0. Alternative (rectilinear-only gap) rejected — needlessly stricter and diverges from TS's square-based feel.
- **Tests derived from the requirement, not the diff.** New cases assert gap outcomes (1-cell gap accepted at adjacent=1, 2-cell gap accepted at adjacent=2, 3-cell gap rejected at adjacent=2) computed independently from the geometry; the two "accepted" cases must fail on the un-patched code. Existing touching/no-neighbor/stats-less tests stay untouched — they are valid under both semantics. Test geometry: neighbor registry entry with cells `[(3,3)]`, 2x2 footprint origins `(5,3)`, `(6,3)`, `(7,3)` giving min distances 2/3/4.
- **Doc comments over API changes.** `EntityData.adjacent` keeps its name and type; only its doc comment is reworded to gap semantics. No data migration needed — `adjacent = 2` files start behaving as authored.

## Risks / Trade-offs

- [Tests could be written to mirror the implementation rather than the requirement] → Expected values derived from the cell geometry table (distances 2/3/4 = gaps 1/2/3), and regression rule applied: failing cases verified against the un-patched build before the fix.
- [Loosening placement could let players spread further than intended] → That is the intent per TS; `adjacent = 2` data is unchanged and the rejection boundary (gap 3 rejected) is test-pinned.
- [Spec/code drift on the `<= 0` bucket] → The delta explicitly documents the divergence from TS (0 = must-touch, negative = disabled) so a future walls change inherits a decision, not a surprise.

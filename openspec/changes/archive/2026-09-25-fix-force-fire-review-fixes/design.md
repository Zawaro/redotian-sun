## Context

`add-force-fire-ground-targeting` shipped cell-occupant and cell-overlay damage for ground shots. A post-archive review found six defects. Four are implementation drift against requirements that already state the intended behavior; two need a requirement clarification. `EntityFactory` plays impact FX/sound from the shared `HealthComponent.damage_taken` signal, so "one impact per hit" becomes "one per victim" when a shot damages both an entity and an overlay.

## Goals / Non-Goals

**Goals:**

- One impact report (FX + sound) per resolved shot.
- No overlay registry scan for warheads that cannot damage overlays.
- Ground projectiles respect max range.
- Force-fire shroud gate judged on the clicked cell.
- Minimap orders target the deck surface.
- Close the archived manual task.

**Non-Goals:**

- Bib-cell targeting for buildings (finding #4) — deliberately not fixed; bib cells are walkable dock pads, and adding them to `_building_cells` would block docking/pathing. A separate targeting index is a design decision for later.
- Retuning movement constants, projectile speeds, or animation.

## Decisions

### D1: Exclude cell overlays at the per-victim choke point, no global suppression flag

`_on_entity_damaged` returns early when `SpatialHash.is_overlay_entity(entity)`. Overlay damage is applied by the warhead-gated cell pass, whose caller (`CombatComponent` / `ProjectileController`) already plays the single report via the entity victim or the `not entity_hit and not overlay_hit` fallback. This is smaller and more robust than a begin/end suppression counter, and it keeps the report tied to the one place that knows whether a real victim existed. The `impact_played` signal on `EntityFactory` is the observability seam the regression test counts; `play_impact_effects_at` becomes an instance method so it can emit.

Alternatives considered: a depth-counted suppression flag around the overlay loop (rejected — global mutable state for a fixed set of victims); passing `emit_report=false` through `HealthComponent.take_damage` (rejected — suppresses the general signal, not just the impact report).

### D2: Gate the overlay scan on the warhead flags

`find_cell_overlays` returns early when `not can_damage_walls and not can_damage_tiberium`. The per-overlay `_overlay_damage_allowed` filter already produced the same result, but only after the O(bridges) `"bridge"` group walk. This is the correct cheap gate; `has_bridge_on_cell()` is not, because its default `level = -1` scans the whole `_bridge_cells` registry.

### D3: Ground max-range fizzle reached without a new return

The ground branch of `ProjectileController._physics_process` now frees the projectile at `_max_range` as the first arm of its `if/elif/else`, reusing the branch's single `return` (gdlint caps returns). Entity-path behavior is unchanged.

### D4: Shroud gate uses the clicked position

`OrderSystem` passes `target_pos` (raw) instead of `bounds.pos` (clamped) to `_ground_shroud_gate`. The order is still issued/clamped through `bounds.pos`; only the shroud decision moves to the clicked cell, restoring the existing requirement's wording.

### D5: Minimap resolves the top surface

`Minimap._handle_click` derives the cell's top surface level from `TerrainSystem.get_cell_surface_levels`, sets the world `y` to that surface's height, and sets `MOD_TARGET_LEVEL`. This applies to every minimap order (plain, queued, force-fire), making a minimap click match the world click's level semantics.

### D6: Archived task closed rather than history rewritten further

The archived task 8.4 is marked complete with a note that its cases are covered by automated tests. This is a judgment call: the repo has 29 archived task files with open boxes, so the systemic fix is a CI/archive guard, not per-file edits.

## Risks / Trade-offs

- [Excluding overlays could silence an overlay-only hit] → the caller's fallback plays the report when neither an entity nor an overlay was hit; for overlay-only hits `overlay_hit` is true, so the fallback also does not double up. Covered by `test_ground_blast_resolves_one_cell_for_both_passes` (damage) + the new report-count test.
- [Minimap now sets `MOD_TARGET_LEVEL` for plain orders] → a minimap click on a bridge cell moves onto the deck instead of under it; intended, matching the world viewport.
- [Bridge group is small] → D2 is a constant-factor win, not an algorithmic one, unless maps carry many bridge pieces.

## Migration Plan

Single change, no save/format migration. Land the code + tests + this change, archive it (no runtime rollback needed; revert if playtest regresses). No scenes touched.

## Open Questions

- Should bib cells resolve their building for force-fire? (finding #4, deferred)
- Should `default_projectile_speed` and animation playback move to the 2× base? (carried from #458)

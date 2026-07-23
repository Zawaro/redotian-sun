## Context

FactoryComponent is currently a thin data wrapper with dead code: `factory_type` (never read by ProductionManager), `free_unit` (handled by FreeUnitComponent), and `can_produce()` (never called). ProductionManager bypasses FactoryComponent entirely and reads EntityData directly through BuildingManager entries.

The production system needs a proper building-level interface: buildings should declare what they produce, define exit points for units, and manage primary building selection. This aligns with OpenRA's architecture where `Production` trait on buildings is separate from `ProductionQueue` on the Player actor.

## Goals / Non-Goals

**Goals:**
- Make FactoryComponent the building-level production interface
- ProductionManager queries FactoryComponent via group-based discovery
- Add ExitComponent for exit point definition (used by production, dock release, repair)
- Add RallyPointComponent for post-exit path management
- Wire primary building toggle with same-type sibling clearing
- Wire ArtComponent to play door animations from ArtData fields

**Non-Goals:**
- Low power production penalty (belongs with power system, GH issue)
- Multiple exit points per building (single exit for now)
- Conditional exit points based on unit type
- Production queue UI changes (existing sidebar works)

## Decisions

### 1. Group-based factory discovery

**Decision:** FactoryComponent adds itself to `"factories"` group on `_ready()`. ProductionManager queries the group and filters by `produces` + `player_id`.

**Alternative:** Keep iterating BuildingManager with FactoryComponent check.
**Why:** Group query is O(n) on group size only, not O(n) on all buildings. Cleaner separation — ProductionManager doesn't depend on BuildingManager.

### 2. ExitComponent as separate component

**Decision:** ExitComponent is a standalone component, not a field on FactoryComponent.

**Alternative:** Exit fields on FactoryComponent (exit_cell_offset, etc.)
**Why:** ExitComponent is used by non-factory buildings too (helipad exit, service depot exit). Separating it keeps components focused. FactoryComponent calls ExitComponent if it exists, falls back to free cell.

### 3. No exit style enum

**Decision:** No DOCK/WALK_OUT/DRIVE_OUT enum. Behavior emerges from component composition.

**Alternative:** Style enum on ExitComponent.
**Why:** Only 3 styles, and they're determined by what components the building has (DockHostComponent for dock, ExitComponent for walk/drive). The difference is visual (door animation), which ArtData handles.

### 4. FactoryComponent orchestrates exit

**Decision:** ProductionManager calls `FactoryComponent.on_unit_produced()`. FactoryComponent handles ExitComponent, rally point, and signals `exit_in_progress`.

**Alternative:** ProductionManager handles exit directly.
**Why:** FactoryComponent knows its own building's components. ProductionManager shouldn't need to know about ExitComponent or RallyPointComponent. Single responsibility.

### 5. Primary building on FactoryComponent

**Decision:** `is_primary: bool` on FactoryComponent. `set_primary()` clears same-type siblings.

**Alternative:** Separate PrimaryBuildingComponent.
**Why:** Only factories need primary building. A non-producing building doesn't need this flag. Keeps it simple.

### 6. ArtData drives door animations

**Decision:** ArtData already has `door_anim`, `under_door_anim`, `production_anim`, `pre_production_anim`. ArtComponent listens to production signals and plays the appropriate sequence.

**Alternative:** Separate DoorAnimationComponent.
**Why:** ArtData already has the fields. ArtComponent already handles animations. Adding a new component for 4 fields is overkill.

## Risks / Trade-offs

- **[Risk]** FactoryComponent group registration happens in `_ready()`, which runs after `_add_components()` in EntityFactory. **→ Mitigation:** Use `call_deferred("_register_group")` or register in `_enter_tree()`.

- **[Risk]** Multiple factories of same type might race on `exit_in_progress` signal. **→ Mitigation:** ProductionManager processes one completion at a time (single-threaded `_process()`).

- **[Risk]** ExitComponent fallback (no ExitComponent → free cell) might place unit in unexpected location. **→ Mitigation:** Log warning when fallback is used. Buildings without ExitComponent get one via EntityFactory if they have exit fields.

- **[Trade-off]** Primary building toggle requires querying all factories of same type. **→ Acceptable:** Small number of factories per player (<10), query is cheap.

## Migration Plan

1. Create ExitComponent and RallyPointComponent
2. Refactor FactoryComponent (delete dead code, add produces/is_primary)
3. Update EntityData with exit fields
4. Update EntityFactory to create new components
5. Wire ProductionManager to query factories group
6. Wire ArtComponent to play door animations
7. Update .tres files with exit fields
8. Test: production flow, exit positioning, rally points, primary toggle

## Open Questions

- Should ExitComponent support multiple exit points (e.g., infantry out one side, vehicles out front)? **Decision: Single exit for now, upgrade later if needed.**
- Should RallyPointComponent support pathfinding through waypoints, or just direct movement to final cell? **Decision: Direct movement to final cell, waypoints are visual only for now.**

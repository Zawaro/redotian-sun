## Context

Current state: SpatialHash rebuilds every physics frame, marking cells blocked if any idle MovementController is on them. This 1-entity-per-cell model means:
- Infantry cannot group (3 per cell is a core TS mechanic)
- Vehicles cannot crush enemy infantry (crusher/crushable properties exist but are unused)
- All units go through IDLE → ROTATING → MOVING, even infantry which should face-and-go

The change touches 5 existing scripts, adds 1 new utility, and updates 47 data files. No scene changes.

## Goals / Non-Goals

**Goals:**
- 3 infantry per cell with deterministic sub-slot positions
- Vehicle crush: crusher units kill enemy crushable infantry on cell entry
- Infantry movement: skip ROTATING, face movement direction directly
- Infantry groups: no repulsion between friendly infantry during movement
- Pathfinder awareness: infantry route through cells with < 3 infantry
- Group move pre-assignment: distribute infantry to cells near target on move command

**Non-Goals:**
- Vehicle-vs-vehicle crushing (weight-based, future phase)
- Crush visual/audio feedback (future phase)
- Infantry prone/dodge mechanic (75% warn probability from TS, future phase)
- Sub-cell weapon range adjustments (future phase)
- Ice cracking weight system (out of scope)

## Decisions

### D1: Cell blocking split — separate dictionaries over unified flag system

**Choice:** Add `_infantry_cell_counts: Dictionary` alongside existing `_blocked_cells`.

**Rationale:** Our needs are simple: infantry cells have a count, other cells have a boolean. Two dictionaries (`_blocked_cells` for vehicles/buildings, `_infantry_cell_counts` for infantry) are cheap to maintain in `rebuild()` and simple to query. A unified flag system with per-cell caches would be overkill for 2 cell types.

**Alternatives considered:**
- Unified flag system: rejected — overkill for 2 cell types
- Single dictionary with count for all: rejected — would change `is_cell_blocked()` semantics, breaking existing callers

### D2: Crush timing — on cell transition, not per-tick

**Choice:** Crush happens when a crusher vehicle steps onto a new cell, checked once per cell transition.

**Rationale:** Matches Tiberian Sun behavior. Per-tick crush checks would be wasteful (checking every frame for crushable enemies on the current cell) and could cause double-crush bugs if timing is wrong. Cell transition is a natural, infrequent event.

**Implementation:** Track `_last_position` in MovementController. On each movement step, detect cell change via `CellUtil.world_to_cell()`. If cell changed and `_crusher` is true, query `SpatialHash.get_crushable_enemies_on_cell()` and kill them.

### D3: Sub-position layout — trigonometric placement with seeded angle

**Choice:** Use Mulberry32 PRNG seeded from cell coordinates to generate a random base angle, then place 3 positions at 120° intervals on a circle of radius `(half_cell - 0.15) * 0.7`.

**Rationale:** Trig positioning guarantees even spacing (exactly 120° apart) with no rejection sampling or fallback. The random base angle gives per-cell variation while remaining deterministic. The 0.15 cell-edge margin keeps infantry within bounds; the 0.7 factor on radius ensures visual separation.

**Alternatives considered:**
- Fixed triangle pattern: rejected — user wanted per-cell variation
- Rejection sampling with PRNG: rejected — can fail on tight margins, adds complexity

**Note on cell capacity:** Original Tiberian Sun supports 5 infantry per cell (dice-dot pattern). We use 3 per cell as specified in the issue — this reduces visual clutter while preserving the grouping mechanic.

### D4: Infantry repulsion bypass — entity_type check in repulsion loop

**Choice:** In `_handle_moving_movement()` repulsion loop, skip push_away when both entities are infantry.

**Rationale:** Simplest possible change — one `continue` guard in the existing loop. No separate movement path, no configuration flag. The sub-slot system handles final positioning; during movement, infantry freely overlap.

### D5: Pathfinder infantry awareness — parameterize `_build_blocked_cells()`

**Choice:** Add infantry cell counts to `_build_blocked_cells()` output when the calling MC is infantry.

**Rationale:** The method already builds a blocked-cells dictionary for pathfinding. Adding infantry cells with count ≥ 3 to this dictionary is minimal change. The calling MC's `_is_infantry` flag determines whether infantry cells are included.

**Alternative considered:** Separate `build_infantry_blocked_cells()` method — rejected, duplication for a one-line difference.

### D6: Group move pre-assignment — SelectionManager splits infantry/vehicles

**Choice:** In `request_move()`, separate infantry from vehicles. Infantry get cells near target (max 3 per cell), vehicles use existing offset logic.

**Rationale:** The current offset-grid approach works for vehicles but would pack infantry 1-per-cell. Pre-assigning infantry to cells with capacity ensures they distribute naturally. The `_find_infantry_cell()` helper spirals outward from target to find cells with room.

## Risks / Trade-offs

- **[Risk] Existing tests assume 1-per-cell** → New tests added; existing SpatialHash tests don't test infantry-specific behavior (they manipulate `_blocked_cells` directly). `_infantry_cell_counts` is additive, doesn't change existing semantics.
- **[Risk] Repulsion bypass may cause infantry to stack visually during movement** → Sub-slot assignment on arrival handles final positioning. During movement, brief overlap is acceptable and matches TS.
- **[Risk] Crush happens silently (no visual/audio feedback)** → Documented as non-goal. Future phase adds crush sound + death animation.
- **[Trade-off] Trig positioning adds complexity over fixed positions** → Per-cell variation was explicitly requested. Trig is 10 lines and guarantees valid positions with no fallback.
- **[Trade-off] 47 .tres file edits** → Bulk data update, low risk, matches original rules.ini faithfully.

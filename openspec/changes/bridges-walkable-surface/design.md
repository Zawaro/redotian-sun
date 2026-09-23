## Context

Bridges are `EntityData` overlays (`games/ts/entities/overlay/bridge*.tres`, `rail_bridge*.tres`) with no runtime behavior: `entity_type = 5` (OVERLAY) is excluded from the `"entities"` group, so bridges neither occupy, block, nor permit anything. The current draft models the *low* case as a single ground-level surface: `SpatialHash._bridge_cells` maps one cell to one scalar `surface_height`, `TerrainSystem.get_land_type()` and `get_cell_surface_height()` read it, and `BridgeComponent` publishes `{surface_height, is_end, piece_id}`. Unit Y and pathing height funnel through `TerrainSystem.get_cell_min_height()` / `get_cell_surface_height()` and `MovementController._memoized_smooth_height()`. The ice feature (`IceComponent` + `SpatialHash._ice_cells` + a `Pathfinder` carvout) is the precedent for an overlay that changes traversability and reverts when destroyed.

That single-surface model cannot express Tiberian Sun. Per the OpenTS manual, *Movement and terrain* (`manual/content/systems/movement-and-terrain.md`, https://github.com/OpenTS-Developers/OpenTS):

> "A cell is not a single place to stand. It is divided into several places, each occupied on its own. … A cell spanned by a bridge deck holds a second, independent set of places for the deck, so the ground under the deck and the deck itself are occupied separately."

> "A cell spanned by a bridge is two places. It is asked about at the deck's height or at the ground beneath it, and the terrain figure is skipped entirely for the deck, which is how a tracked vehicle whose `[Water] Track=` reads `0` crosses a river. At ground level under that same bridge it is refused exactly as it would be in the open."

> "**One level apart.** Allowed only across a ramp, and the ramp must be the cell at the lower of the two heights… **Four levels apart.** The bridge case. Allowed only where the cell beneath the deck is marked as spanned…"

> "A step of two or more height levels is costed from the `[Road]` row rather than from the destination's own land type, which is how a vehicle keeps its speed climbing onto a bridge deck over water."

`docs/research/deep/ts-core.md` TS-CORE-042 — Bridges records the same engine facts and constants: a bridge cell is deck + ground beneath; `BRIDGE_CELL_HEIGHT = 4`; a four-level step is allowed only across a span and ±1 only across a ramp; a vehicle on the deck skips the terrain figure; `BridgeStrength=1500` with whole-piece destruction; the `BridgeRepairHut` replaces engineer restore/capture and picks rail vs road repair from a 5×5 block; a projectile crossing the deck plane detonates at deck height and a blast's nine-cell sweep splits deck vs ground occupants by the blast's own height. `MAX_HEIGHT = 10` and `HEIGHT_STEP = 0.815` are the engine's terrain constants (`TerrainSystem.gd:6-7`).

This design replaces the single-surface model with the full one.

## Supersedes

**Decision: the previous single-surface bridge model is superseded.** The `_bridge_cells` registry storing one scalar `surface_height` per cell, the "bridge surface = one place" assumption, the ground-level-only low bridge as the whole design, and the "ships under bridges / no Z model" non-goal are all replaced. This is not an extension: cell identity gains a level, occupancy becomes per-level, pathfinding nodes become `(cell, level)`, and the boxed `surface_height` scalar becomes a stack of level surfaces. Existing single-surface bridge tests and spec requirements are **rewritten** to the level model, not weakened or deleted. The prior `BridgeComponent`, overlay resources, `bridge` land type, and `cell_pins` persistence are retained as starting points and reworked — not thrown away.

## Goals / Non-Goals

**Goals:**
- A cell exposes a surface stack: ground (level 0) plus deck levels above, bounded by `MAX_HEIGHT`.
- Land type, walkable surface height, and occupancy are queryable per level; **default level 0 preserves every existing caller** and current map behavior.
- A bridge deck is a parallel place-set at its own level; ground traffic beneath a high deck is judged as open ground.
- TS height transitions: level OK; ±1 only across a ramp (the lower cell); ±N×4 only across a spanned deck; else refuse. ≥2-level steps cost from the Road row; the deck surface skips the terrain figure.
- Low bridge, high bridge (one authored flat span grade), rail bridges (high only), and N stacked extra-high decks.
- Bridge ends are `TerrainObject`s (cliff + 3-cell road cut) applied by a stamp-to-grid consumer and persisted through the existing `cell_pins` JSON.
- A ground unit drives across a low deck and across a high deck; another unit drives on the ground *under* a high deck at the same time.
- API + specs + tests only.

**Non-Goals:**
- Actual destruction/damage gameplay (#250). Bridge strength, the repair hut, and whole-piece break via `piece_id` are foundation-only here.
- Map editor placement UI / rotation tooling (#228).
- Bridge geometry/art beyond placeholders; projectile-deck detonation, blast split, and falling-off bridges (noted in TS-CORE-042, deferred with combat work).
- Shrouded/fog interaction with decks.

## Decisions

**D1. A cell holds an ordered surface stack, not one height.**
`TerrainSystem` gains a per-cell stack: level 0 is the terrain surface; each deck level is stored above it, bounded by `MAX_HEIGHT = 10`. Land type, walkable surface height, and occupancy queries accept a `level` argument (default 0). Level 0 returns exactly today's values, so no existing call site changes behavior. Alternative rejected: a separate `BridgeSystem` autoload with its own height map — it would duplicate the terrain surface accessor and leave two sources of truth for unit Y.

**D2. Height-parameterized query API with level 0 as the compatibility contract.**
`get_land_type(cell, level = 0)`, `get_cell_surface_height(cell, level = 0)`, and the occupancy/reservation predicates gain an optional level. Absent a level, every caller sees the ground surface, so `PathCostCache`, `MovementController`, HUD, and existing tests are untouched until they opt in. This is the migration lever: land the stack, keep level 0 green, then move consumers one at a time.

**D3. A deck is a parallel place-set, mirroring sub-slots.**
The sub-slot model already gives a cell `shared_slots_per_cell` independent places (`CellSubPositions.get_sub_positions`, `CellSubPositions.get_slot_count`). A deck level gets its own set of places, so ground and deck occupancy are counted separately — a limit of N ground units under the deck does not consume deck slots. `SpatialHash` occupancy/blocking and `CellReservation` claims become level-scoped; `CellReservation` keys claims by `(cell, level)`. Alternative rejected: one shared place pool with a height tag — it collapses two independent capacities into one and breaks the "occupied separately" rule.

**D4. Height transitions follow the TS rules, and ≥2-level steps cost from the Road row.**
Transition from `(cell, level)` to a neighbor:
- same level → allowed;
- ±1 level → allowed only across a ramp, and only when the ramp is the lower of the two cells;
- ±N×4 (bridge) → allowed only where the lower cell is spanned by a deck and the destination is that deck's level;
- anything else → refused.
A step of two or more levels is costed from the locomotor's **Road** multiplier, not the destination land type. On a deck the terrain figure is skipped entirely: deck passability and cost are the road row. This is the manual's rule and TS-CORE-042's "four levels allowed only across a bridge span; ±1 only across a ramp". Alternative rejected: deriving cost from the deck's land type — the resource says Road explicitly, and it is what lets a wheeled unit keep speed onto an over-water deck.

**D5. Bridge ends are `TerrainObject`s applied by a new stamp-to-grid consumer.**
A high-bridge end is a cliff with a 3-cell road cut, authored as a `TerrainObject` (`cell_type = "cliff"`, per-cell `land` + `corners`). A new runtime consumer reads the object's `cells` and applies `land` and `corners` to the terrain grid at the object's placement, then pins those cells. Persistence uses the **existing** `cell_pins` map JSON (`pin_cell(cell, object_id)` + `get_pin`), so no new JSON section is introduced and the existing pin overlay round-trips the ends. This is the first runtime (non-editor) consumer of a `TerrainObject`; the editor currently stamps them. Alternative rejected: a bespoke `bridge_ends` JSON array — it duplicates the pin overlay and adds a schema key for no new information.

**D6. Low vs high vs rail.**
- **Low bridge**: deck ~0.5 height step up (thickness upward), slope end pieces; normal pieces destructible, end pieces indestructible; rendered as overlay entities.
- **High bridge**: deck ~4 height steps up on **one authored flat span grade** (thickness downward); **all** cells indestructible; owns cliff / 3-cell-road-cut terrain ends (D5).
- **Rail bridge**: exists only as a high bridge variant; it never appears as a low bridge.
The `bridge_kind` enum on `EntityData` carries low/high/rail; deck grade/rise and level are authored data, not hardcoded. A deck's walkable height is the cell's minimum terrain corner plus the authored `bridge_rise`, chosen so a flat span stays flat and a deck cell does not inherit a neighbouring end's raised corners; a per-piece authored absolute grade would be needed for non-flat spans. Alternative rejected: a single bridge kind with runtime height probing — the destructibility and end-geometry differences are structural, not incidental.

**D7. N stacked decks from the start, bounded by `MAX_HEIGHT`.**
Decks are not limited to one level. Additional authored deck levels stack over the same XZ at different Y, bounded by `MAX_HEIGHT`, forming the pre-existing "extra-high bridge" case. Each level is an independent place-set (D3) and participates in the height rules (D4). N=1 covers low/high; N>1 covers extra-high. Alternative rejected: hardcode exactly two surfaces (ground + one deck) — TS maps use more, and the bound already exists.

**D8. A* nodes are `(cell, level)`; the cost cache is keyed by `(cell, level)`.**
Pathfinding state becomes a pair so a high deck and the ground beneath are distinct nodes. Neighbor expansion evaluates D4 transitions and uses the deck's road cost. `_cell_height` reads the level's surface height. The per-cell cost cache (`PathCostCache` / `_cell_cost`) is keyed by `(cell, level)` and its generation bumps on bridge/level changes, so adding or destroying a deck invalidates cached data. A unit can path on the ground under a high deck because the ground node at level 0 remains passable and the deck node does not block it.

**D9. Mouse picking disambiguates by level.**
A ray that hits a high deck resolves to the deck level (so the click selects the deck surface and its occupants). The ground level beneath remains selectable — picking reports both candidates and the ground stays reachable, honoring "two places". Alternative rejected: always pick the highest surface — it makes the ground under a deck unclickable.

**D10. Damage/repair is foundation only.**
`BridgeStrength`, the repair hut, and whole-piece break via `piece_id` are represented in data and hooks; actual destruction, repair gameplay, projectile-deck detonation, and blast splitting are #250. This change ships the surface model and its tests.

## Risks / Trade-offs

- [Scope] The full model touches terrain, pathing, occupancy, picking, data, and scenes. → Sequenced into seven phases in `tasks.md`; each phase is independently verifiable and earlier phases default to level 0.
- [Performance] Keying occupancy, reservations, and costs by `(cell, level)` multiplies grid entries. → A level is a small int appended to the existing integer cell key; the common case is one level, and the extra map level only materializes where a deck exists.
- [Cache staleness] A new deck changes surface height and transitions without a terrain-mutation signal. → Bridge register/unregister bumps the path-cost generation and invalidates the `(cell, level)` entries, as blocker changes already do.
- [Migration] Packed scenes and call sites predate the level parameter. → Every new parameter defaults to 0; level 0 returns today's values, so existing `.tscn`s and callers keep working until migrated.
- [Flat-span authoring] The high-bridge deck is a single authored flat grade; varying terrain under the span would otherwise tilt it. → Deck height is authored data (grade/rise); the stamp/grade fixture enforces a flat span. Editor enforcement is #228.
- [Rail] Rail bridges need rail-only movement rules not fully modeled here. → This change treats rail as a high-bridge variant with its own `bridge_kind`; rail-specific movement restrictions remain for the movement work.

## Migration Plan

Additive and level-0-first. Land the surface stack and level-parameterized queries; every existing caller passes no level and reads ground, so behavior is byte-identical. Then move consumers (pathfinder, mover, picking, occupancy) to pass a level one system at a time. New data fields (`bridge_kind` low/high/rail, deck grade/rise, level) default to inert values. No packed-scene schema change; existing maps without bridge entities load unchanged. The single-surface `_bridge_cells` scalar is replaced by the level-aware registry; existing bridge overlay resources and the `bridge` land type are retained and reworked. Rollback is branch deletion — no persisted state depends on the change beyond overlay entities already expressible in the `entities` array and pins in `cell_pins`.

## Open Questions

- Exact low-bridge deck lift (~0.5 step) and high-bridge rise (~4 steps) values — authored defaults now, art/balance pass later.
- Whether the deck road cost uses the locomotor's `road` multiplier exactly or a bridge-specific row — default to `road`, confirm during implementation.
- Maximum useful deck count under `MAX_HEIGHT = 10` (extra-high) — support N generally, tune authored maps later.
- High-bridge end road-cut width: the brief says a "3 cell wide" road cut while a bridge piece is a 3-cell row; the shipped end tiles currently cut a 1-wide × 3-long road. Confirm whether the cut should be 3 cells across (deck width) or a single 3-cell lane, and re-author the end tiles if needed.

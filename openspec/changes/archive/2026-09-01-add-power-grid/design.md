# Design — Add Power Grid

## Context

`PowerComponent` (scripts/components/PowerComponent.gd) is an 18-line data wrapper: signed `power: int` copied from `EntityData.power`, plus a data-level `powered: bool` meaning "requires power". The `.tres` data already carries the sign convention (producers `+100`, consumers `−50`/`−150`), but no system aggregates it. The issue (#33) assumed GlobalRules already held the low-power coefficients via #26 — it does not (#26 closed without them); they are added here.

Existing infrastructure this design builds on:

| Piece | Relevance |
|---|---|
| `SpatialHash` autoload | Precedent for tree-signal-driven registration (`node_added`/`node_removed`) |
| `StatsComponent.player_id` | Per-entity ownership, assigned before `add_child()` in `place_building` (BuildingManager.gd:171→178) — ordering already correct for tree-signal registration |
| `ProductionManager._get_production_speed()` cache | The low-power multiplier hooks here; cache invalidation machinery (`_speed_cache.clear()`) already exists |
| `ArtComponent` `set_process` toggles (lines ~104/115) | Existing pause/resume mechanism for animations |
| `EntityFactory._add_power_component()` | Proves PowerComponent reaches every spawn path (BuildingManager, MapLoader, DeployComponent) — all funnel through `create_entity()` |

## Goals / Non-Goals

**Goals:**
- Per-player power aggregation covering every spawn path, with immediate transitions
- Powered-down shutdown fan-out to combat, radar, and animations via per-entity signals
- Low-power production slowdown through the existing speed cache
- Selected-producer `POWER = {output}` / `DRAIN = {drain}` label
- TS-faithful data pass (`powered = true` on the affected structure set)
- TS-style sidebar power bar and build-cameo power tooltips

**Non-Goals:**
- `toggle_power` manual shutdown (data field exists; wiring later is one more recompute trigger)
- Power sharing radius / grid connectivity (deferred in the issue itself)
- Red-light/smoke powered-down visuals, radar-driven minimap reveal
- Producer-side shutdown (producers are always online in this change)

## Decisions

### D1: Tree-signal registration over BuildingManager events

PowerGrid connects `get_tree().node_added` / `node_removed` (SpatialHash precedent) and registers any node owning a `PowerComponent`.

- **Why**: Buildings enter through three doors — `BuildingManager.place_building()`, `MapLoader` (starting bases), `DeployComponent` (MCV deploy). Only the first emits `building_placed`; hooking manager signals would silently miss every starting base. Death falls out of `node_removed` for free.
- **Alternative rejected**: EntityFactory calls `PowerGrid.register()` inside `_add_power_component()` — couples factory to grid and still needs exit-tree handling, so the same machinery gets written anyway.

### D2: Purely event-driven, no polling, no reconcile pass

Recompute happens on registry add/remove only.

- **Why**: Unlike SpatialHash, buildings never move — the registry only changes at add/remove time, which tree signals catch completely. A periodic reconcile (SpatialHash-style) would be dead code.
- **Deliberate shortcut**: `queue_free` is deferred, so a destroyed plant lingers in the registry for the remainder of the frame — one frame of stale sums is invisible in play. `ponytail:` per-player dirty-flag recompute if multiplayer replay ever needs frame-exact sums.

### D3: Two change kinds, two channels

A recompute diff produces two distinct signals:

- **Boundary crossing** (sum sign flips) → `PowerComponent.set_online(bool)` on each affected `powered = true` structure → per-entity `power_state_changed` fan-out (combat gate, radar query, anim pause/resume).
- **Rate drift** (ratio changed, sign didn't) → `grid_state_changed(player_id)` only, consumed by ProductionManager's cache invalidation.

- **Why**: Fan-out touches N entities and is only correct at boundaries; rate drift touches exactly one consumer. Conflating them spams the tree on every building change.
- **Naming note**: `EntityData.powered` means *requires* power (data); runtime state is `PowerComponent.is_online` — deliberately different names to avoid the powered/offline confusion in specs and code.

### D4: Low-power math — signed sums, one formula

```
sum   = output − drain          (output = Σ positive, drain = Σ |negative|)
low power ⇔ sum < 0
rate  = lerp(worst, best, clamp(output / drain, 0, 1))    when sum < 0
rate  = 1.0                                                 otherwise
```

- **Why**: `sum < 0` implies `drain > 0`, so the ratio is always well-defined — no zero-division corner exists. Ratio `→ 1` approaches `best` (mild deficit), `→ 0` approaches `worst` (near-blackout), matching TS `Best/WorstLowPowerBuildRate`.
- **Issue deviation**: The issue lists "Production halts" under shutdown effects; this design keeps factories producing at reduced rate (factories are not `powered = true` in data, and TS behavior is slowdown). A hard halt would make blackout a death sentence rather than a scramble.

### D5: Combat gate is a poll, not a subscription

CombatComponent checks its sibling `PowerComponent.is_online` at the top of its existing `_physics_process` gate; ArtComponent subscribes to `power_state_changed` (pause/resume must happen exactly at transition).

- **Why**: Polling a local sibling flag keeps combat working even when an entity is constructed without the grid (hermetic unit tests), and per-frame cost is one bool read. Art needs edge-triggered behavior, so it takes the signal.
- **Fallback**: when no `PowerComponent` sibling exists, behavior is identical to today — no regression path for units.

### D6: Label is a per-frame pull in SelectionOverlay

The green two-line `"POWER = {output}\nDRAIN = {drain}"` text is drawn in the existing `_do_draw` loop for tracked entities whose `PowerComponent.power > 0` and that are selected (not hovered), centered in the already-computed `bracket_rect`. Numbers come from `PowerGrid.get_output(pid)` / `get_drain(pid)` each frame.

- **Why**: The overlay redraws every frame anyway — zero new signals, zero cache invalidation, live numbers for free. Trigger is data-driven (`power > 0`), so future advanced plants label themselves without a hardcoded list.
- **Structure fix**: `_collect_entities` originally skipped `select_box_type == Structure` entirely — starving the label for the exact entity it was built for. Structures are now collected with overlay brackets/health bars/pips suppressed (they render SelectComponent's 3D wireframe box); the overlay contributes only the label. `_collect_entities` also clears at entry so direct test calls are order-independent.

### D7: Ownership via StatsComponent.player_id

No new ownership registry. PowerGrid reads `StatsComponent.player_id` at registration time (already set before `add_child()` in every placement path).

- **Risk accepted**: map-load entities must set `player_id` before `add_child` too — verified for `place_building`; the map-loader path gets a task-level check and test.

### D8: Sidebar power bar — per-frame pull, fixed 2000 scale

The TS-style twin power bar lives on the sidebar's left edge (`PowerBar` Control hosted in `Sidebar.tscn`, cameo panel inset to clear it): a black column backing a green fill (output) with a red fill (drain) drawn in front, both bottom-aligned and clamped to the bar height. On deficit the red bar rises above the green. Scale is fixed at `MAX_POWER = 2000` — an output of 2000 fills the bar, everything below is relative.

- **Why per-frame pull**: `grid_state_changed` fires only on boundary/rate drift — a healthy-grid output change emits nothing, so signal-driven updates would miss sums changes. The bar reads `get_output`/`get_drain` for the local player and eases `_displayed` toward the computed targets every frame, matching the SelectionOverlay precedent. Grid lookup goes through `get_node_or_null("/root/PowerGrid")` like every other consumer — global-name lookups broke in editor sessions with stale autoload caches.
- **Why fixed scale + power curve**: TS-faithful relative bar; the constant carries an upgrade path to a GlobalRules export if modding ever needs it. Heights map through `(fraction)^0.4` — linear made a single plant invisible (5%), pure log overshot (61%); the power curve puts one plant at ≈ 30% while large bases still spread across the top half. Fills ease with a frame-rate-independent exponential lerp (rate 8/s) and snap on arrival, so placed/sold plants animate rather than snap.
- **Cameo tooltips**: build-cameo tooltips append a signed `Power: %+d` line when `EntityData.power != 0` — data-driven, no special-casing per structure.

## Risks / Trade-offs

- [Map-load entities register without an owner if `player_id` assignment order differs from BuildingManager] → integration test asserts a starting-base power plant is attributed to its map player; registration defers attribution when `player_id` is unset (treated as neutral, not player −1 noise).
- [Signal storms when a large base changes rapidly (e.g. mass sell)] → per-recompute diffing means only *changed* states fan out; a no-op change emits nothing (spec scenario pins this).
- [`grid_state_changed` ↔ `_speed_cache` connection lifecycle] → connect once from ProductionManager `_ready`; PowerGrid tolerates zero listeners (label and combat don't need it).
- [Editor-placed entities polluting sums] → map-editor entities carry the `is_map_editor` meta guard pattern already used for gameplay logic; PowerGrid skips entities under an editor-flagged root (same check used by ResourceGrowthSystem).
- [Autoload ordering: PowerGrid connects tree signals in `_ready()` (SpatialHash precedent — autoloads ready before the gameplay scene loads, so no entity is missed)] → no action needed; matches the working SpatialHash idiom.

## Migration Plan

Additive only: one new autoload entry, new signal listeners, and a data pass flipping `powered = true` on structure `.tres` files. Rollback = remove the autoload entry; all other code paths degrade to current behavior (missing grid → rate 1.0, combat unaffected, no label). No packed-scene or save-format changes.

## Open Questions

None blocking. The exact `powered = true` structure list is verified against TS `rules.ini` during implementation (candidates: both radars, stealth generator, firestorm generator, missile silo, temple of nod, upgrade center, laser fence posts).

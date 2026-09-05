## Context

TransportComponent (scripts/components/TransportComponent.gd) today is counters and plumbing: a cargo dictionary for harvesters, `add_passenger`/`remove_passenger` int math, and a broken ENTER order stub that only fires when a transport is selected and another transport clicked. The dock machinery (DockHost/DockClient/DockUnload) covers harvester→refinery flows. Order routing is component-based: UnitOrderGenerator asks each selected entity's components for cursor/order against a clicked target, and OrderResolver picks the highest-priority result. Entity discovery (targeting, selection, spatial hash, rendering) is group-scan based (`entities`, `selectable`, `drag_selectable`), with persistent-group semantics re-establishing membership on tree re-entry.

## Goals / Non-Goals

**Goals:**
- Infantry load into friendly stationary transports with free seats; passengers survive as real nodes (health, veterancy, weapons intact) and can unload again.
- Unload via the existing deploy command (hotkey or hover-self DEPLOY cursor), sequential eject, interruptible.
- Destroyed transports eject passengers.
- Per-passenger colored seat pips on the selection overlay.

**Non-Goals:**
- Passenger fire-out (weapons stay dormant while aboard; transport uses its own weapon and earns its own veterancy exp).
- Speed penalty when loaded.
- Vehicle/aircraft passengers — infantry only.
- A persistent "underground" state machine for subterranean units (stationary = surfaced today).
- Per-seat pip coloring by infantry *rank*; color is per entity type via `pip_color`.

## Decisions

### D1: Passengers are detached real nodes, not snapshots
`remove_child()` the infantry node, hold the `Node3D` in TransportComponent, `add_child()` back on disembark.
- **Why over snapshot+recreate**: health/veterancy/weapons survive for free; no EntityFactory re-run; no state duplication to keep in sync.
- **Why over hide-in-place**: hide-in-place needs an "aboard" guard in every targeting/vision/crush/render system. Detach gets all of that from Godot semantics: persistent groups drop off-tree nodes (so group scans — the codebase's only entity-discovery mechanism — see nothing), `exit_tree` hooks clean SpatialHash/selection/vision registration, re-entry re-registers.
- TransportComponent stores passengers as `Array[Node3D]` plus a parallel `Array[Color]` of pip colors captured at board time.

### D2: Load order lives on the infantry side (new PassengerComponent)
New `scripts/components/PassengerComponent.gd` implements `get_cursor_for_target`/`get_order_for_target`: ENTER cursor/order when the target is a friendly transport with `current_passengers < passengers`, the transport's MovementController is not moving, and the ordering infantry is not already aboard. This mirrors how `HarvestComponent` returns ENTER against refineries (harvester→refinery dock orders) — the established pattern is the ordering unit's component offering orders against compatible targets.
- The old transport→transport ENTER stub in TransportComponent (`get_cursor_for_target`/`get_order_for_target`) is deleted.
- EntityFactory attaches PassengerComponent when `entity_type == INFANTRY`.
- The order's action lambda issues a plain move order to the transport's cell (no retarget loop — Q5 decision). Arrival handling: when the infantry finishes that move, if it ends adjacent to the transport and the transport is still friendly, stationary, and has seats, it boards; otherwise it idles where it stopped.

### D3: Load has no queue
All ordered infantry walk as independent move orders; first-come-first-served on arrival while seats remain; overflow idles outside. No slot booking, no CellReservation involvement. Tiberian Dawn's queue behavior is explicitly unwanted.

### D4: Unload is the deploy command
TransportComponent gains `can_unload()` (has passengers, MovementController not moving, `TerrainSystem.get_land_type` on the transport's cell is not water) and `execute_unload()`.
- Hover-self shows the DEPLOY cursor when `can_unload()` — same shape as `DeployComponent.get_order_for_target`'s self-target branch (priority 15).
- The deploy hotkey path in MouseHandler (currently `DeployComponent` only, MouseHandler.gd:96-99) also calls `execute_unload` on selected transports.
- `execute_unload` starts a sequential eject: one passenger per `GlobalRules.unload_interval` seconds, each re-added at the nearest free land cell (`MovementController._find_nearest_free_cell` + infantry sub-slot assignment) with a small idle placement.
- Subterranean transports: stationary = surfaced today (dig is movement-time only, MovementController.gd:569-574 has no persistent underground state); if a true underground state lands later, `can_unload()` gains that gate. Spec records the stationary gate as the surfaced requirement.

### D5: Interrupts are polling plus the stop hook
The unload sequence cancels when the transport receives a move order (TransportComponent polls `MovementController.is_moving()` each physics tick while unloading — any move, including queued orders firing, cancels) and when the stop command runs (the stop handler notifies selected transports to cancel — same place stop halts movement/harvesting/combat).

### D6: Eject on death
TransportComponent listens to HealthComponent's `health_zero`: re-add all held passengers at nearest free land cells before the transport tears down (RA2-style eject, Q4 decision). Guards against the transport being freed while still holding nodes.

### D7: No combat wiring at all
Passenger nodes off-tree don't process, so their CombatComponents are naturally inert — passenger weapons are dormant without any code. The transport's own StatsComponent/veterancy is untouched (D1's alternative — aggregating weapons — was rejected in planning).

### D8: Seat pips color per passenger
- `EntityData.pip_color: Color` (default white) export, `##` doc comment.
- PassengerComponent captures `pip_color` in `configure(data)`; TransportComponent records it at board time into the parallel color array.
- SelectionOverlay `_make_pip` gains an optional color field; `_gather_pips` fills passenger pip dicts with the per-seat color; `_draw_pips` uses it instead of the hardcoded `Color.WHITE` (fallback white).

### D9: Unload interval is one GlobalRules knob
`GlobalRules.unload_interval: float` (seconds between ejects) — game-wide constant matching the GlobalRules pattern for combat/timing constants; no per-transport data field.

## Risks / Trade-offs

- [Stale selection: infantry selected when it boards] → PassengerComponent's board path explicitly removes the boarding node from SelectionManager before detach; group cleanup alone leaves the selection list holding a dead entry.
- [Transport freed while passengers held] → D6 ejects on `health_zero` before teardown; `unload all remaining` in `_exit_tree` as a backstop for scripted frees.
- [Re-added infantry lands on a cell that became blocked mid-ride] → eject uses `_find_nearest_free_cell`; if none exists the passenger stays aboard (unload retries next interval; eject-on-death falls back to the transport's own cell).
- [Unload pacing and frame independence] → accumulator-based timer on `_physics_process`, honoring the frame-rate-independent-timing spec.
- [OrderResolver interactions: infantry with PassengerComponent + MovementController both answer] → ENTER priority (10, matching the existing transport/harvest ENTER orders) beats MOVE; transport full/moving returns no ENTER so MOVE falls through naturally.
- [Harvesters are also transports (`passengers > 0 or harvester`)] → PassengerComponent only attaches to INFANTRY; harvester cargo pips untouched; harvester unload path (DockUnload) unaffected.

## Migration Plan

Additive: new component, new EntityData/GlobalRules fields, new overlay pip field. No packed scene changes (components attach via EntityFactory), no OrderSystem changes. Existing `.tres` files load unchanged (`pip_color` defaults). Rollback = revert branch; no data migration.

## Open Questions

None — all decisions resolved in planning (scope, detach model, stationary-only load with no queue, deploy-command unload with sequential eject and interrupts, eject-on-death, no fire-out, no speed penalty, pip colors).

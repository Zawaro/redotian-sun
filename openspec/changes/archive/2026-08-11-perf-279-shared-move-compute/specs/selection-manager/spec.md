## MODIFIED Requirements

### Requirement: Batched move dispatch
SelectionManager SHALL dispatch pending moves in batches of 8 per frame via `_process()`. This prevents frame spikes when moving large groups. Each pending mover SHALL resolve its path via greedy-first movement: the unit's MovementController attempts bounded greedy descent toward its assigned cell (`Pathfinder.try_greedy_step`) and falls back to per-unit `Pathfinder.find_path` only when greedy descent stalls. SelectionManager SHALL NOT compute group-wide frontiers or precompute paths for sharers; every mover's path is resolved per-unit at dispatch time. SelectionManager SHALL keep one batch-lifetime terrain-cost cache (`Pathfinder` per-cell terrain cost memo) alive across the drain frames of a single move order so all units in the order share cost data; the cache SHALL be discarded (or its generation invalidated) when blocked/reservation state changes. SelectionManager SHALL resolve the `TerrainSystem` node reference once per move-order batch and pass it into per-unit path resolution (alongside the shared cost cache) instead of re-resolving the autoload for each unit, so the greedy/A* calls never walk the scene tree per step.

#### Scenario: Large group moved in batches
- **WHEN** 20 units are queued for movement
- **THEN** only 8 units receive their move command per frame, completing over 3 frames

#### Scenario: Sharer-only group uses greedy-first per-unit dispatch
- **WHEN** a selection is entirely infantry cell-sharers with one `LocomotorData` and a move is issued
- **THEN** every unit resolves its path per-unit (greedy first, A* on stall) with no group-wide frontier computation, and all units share one batch-lifetime terrain-cost cache

#### Scenario: Mixed selection keeps per-unit dispatch
- **WHEN** a selection contains a mix of sharers and non-sharers (vehicles, crushers, jumpjets)
- **THEN** every unit resolves its path per-unit (greedy first, A* on stall)

#### Scenario: Cache lifetime spans the order drain
- **WHEN** a move order for 50 units drains across ~6 frames
- **THEN** the terrain-cost cache is reused across the drain frames and invalidated when blocked/reservation state changes

#### Scenario: Terrain resolved once per order batch
- **WHEN** a move order drains N units across multiple frames
- **THEN** the `TerrainSystem` node is resolved at most once per batch and threaded into every unit's path resolution (no per-unit, per-step scene-tree lookup)

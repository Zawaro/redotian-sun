## Context

A move order to 50+ infantry costs ~14.6ms/frame of Process time for ~6 frames because `SelectionManager._process` drains 8 pending moves per frame and each `MovementController.set_target_position` runs a full `Pathfinder.find_path` A* (~1.8ms) from a scattered start to its formation cell (all formation cells cluster within a ~4-cell radius of the order target). The reverse-frontier fast path (`compute_frontier`/`reconstruct_path`) proposed in `perf-279-shared-move-lines-group-path` was measured as a regression: reverse Dijkstra has no heuristic, expands a uniform disc over the reachable map, and costs 95ms in a single frame (profile) / 30× slower than per-unit A* (benchmark). The shroud re-stamp fix (phase 1) is already shipped.

Geometry that shapes the design: **destinations cluster, starts scatter.** Any group fast path that assumes clustered starts is invalid. The shared subgraph is the destination disc, not the start side.

## Goals / Non-Goals

**Goals:**
- Eliminate the move-order Process-time spike (14.6ms/frame × ~6 frames → near-zero on open terrain, bounded fallback otherwise).
- Keep paths byte-identical to today's `find_path` whenever full A* is needed (correctness contract).
- Remove all reverse-frontier code and its tests (superseded).
- Keep the batched move-line renderer and the phase-1 shroud fix intact.

**Non-Goals:**
- Resumable/paused A* across frames (Pathfinder surgery + frozen blocked snapshot; too invasive).
- Flow-field/visibility-graph rewrites (architecture changes out of scope).
- Group-wide path sharing (one-path-many-riders requires clustered starts, which is false).
- Reducing the 8-per-frame batch size (peak stays ~1ms/frame after greedy + cache; no need).

## Decisions

### D1: Greedy-first, A* fallback (the headline)
`Pathfinder.try_greedy_step(from_cell, target_cell, blocked, locomotor) -> Vector2i` returns the best strictly-improving passable 8-neighbor, or an out-of-range stall sentinel (e.g. `Vector2i(-1 << 20, -1 << 20)`). `MovementController.set_target_position` walks it from the unit's cell toward the destination with a bounded budget (e.g. 64 steps) and only runs `find_path` from the stalled cell when greedy stalls.

- **Stall = strictly-no-improvement** (every passable neighbor increases distance/cost, or is blocked), with deterministic tie-break: prefer target-direction, then previous heading. This prevents plateau livelock and false A* triggers.
- Greedy neighbor cost uses the SAME model as `find_path` (octile cost, terrain speed multiplier, height penalty, bib penalty, per-locomotor passability, climb tolerance) so greedy and A* agree on easy terrain and fallback fires only on genuinely concave/blocked layouts.
- Fly/jumpjet ignore the climb check (matching `ignores_height`); they stall only on blocked cells, so their greedy descent is exact when no blockers are present.

**Alternatives considered:** reverse frontier (measured regression), one-path-riders (invalid, scattered starts), resumable A* (invasive, late path arrival), coarse macro-cells (scope creep). Greedy-first is the smallest change with the biggest win on the common open-terrain march.

### D2: Per-cell terrain cost cache (the constant win)
`find_path`'s inner loop probes `_cell_height` (4× `terrain.get_vertex`), `get_land_type`, bib, and blocked state per neighbor — the profile's `_cell_height` signal (30ms of the frontier cost, same probe in find_path). Add a memoized per-cell cost lookup keyed by cell: first probe fills it, later probes read the cache.

- **Scope:** safe first step is a per-search-call memo (proves byte-identical output with `test_pathfinder_terrain.gd` unmodified), then extend to batch lifetime (SelectionManager keeps the context across its 8/frame drain).
- **Invalidation:** a generation counter bumps when blocked/reservation state changes; the cache is cleared (or generation-checked) on any bump. Immutable terrain data (height, land type) never needs invalidation.
- **NOT warm-g:** reusing a previous unit's g-scores/closed set is rejected — `g` is cost-from-start, so seeding unit B from unit A's search gives B paths through A's start chain (incorrect). Only terrain *cost data* is shared, never search state.

### D3: SelectionManager owns the cache, dispatches plainly
`request_move` drops all `_frontier_*` gating. `_execute_move` calls `mc.set_target_position(position, false, false, false)` with no precomputed path. SelectionManager creates the batch-lifetime terrain-cost cache context in `request_move` and passes it to `_execute_move`/MovementController for the drain.

### D4: Flyer bypass folded into D1
The ADHD "flyers skip pathfinding entirely" idea was weakened to match reality: `ignores_height` makes their greedy descent stall only on blocked cells, but blocked buildings still force the A* fallback, so flyers get no special case — they simply benefit from greedy-first like everyone. The spec's flyer scenario reflects this (greedy allowed across height steps; A* only on blocked cells).

### D5: Superseding the frontier change
`openspec/changes/perf-279-shared-move-lines-group-path` keeps its `move-line-renderer` and `select-component` deltas (they ship). Its `pathfinder` and `selection-manager` frontier deltas are superseded: this change's `selection-manager` delta MODIFIES "Batched move dispatch" to the greedy-first final state (the main spec never absorbed the frontier), and this change's `pathfinder` delta ADDs the greedy/cache requirements. When archiving the frontier change, drop its two frontier spec deltas.

## Risks / Trade-offs

- **Local minima / plateau livelock** → Fallback fires only on strictly-no-improvement with deterministic tie-break; the concave-pocket regression test (unit must escape via A*) guards it.
- **Greedy and A* disagreement on cost** → Greedy uses the identical cost model; the flat-terrain path-match test (`frontier_matches` style, now greedy-vs-A*) guards it.
- **Cache staleness across blocker changes** → Generation counter on blocked/reservation changes; cache never persists beyond the order drain.
- **Batch cache changing path output** → Cache is memo of immutable terrain + generation-checked blockers; byte-identical diff test proves it.
- **Frontier spec conflict at archive** → `selection-manager` main-spec requirement never absorbed the frontier; this change's delta is the authoritative final state. Archive order: frontier change first (dropping its 2 frontier deltas), then this one.

## Migration Plan

1. Implement D2 cache inside `find_path` (per-call scope) → run `test_pathfinder_terrain.gd` unmodified, must pass byte-identical.
2. Implement D1 greedy step + MovementController loop + D3 SelectionManager cleanup (which removes `compute_frontier`/`reconstruct_path` and frontier tests).
3. Extend D2 cache to batch lifetime; run full suite.
4. Update `perf-279-shared-move-lines-group-path`: drop `pathfinder` and `selection-manager` frontier spec deltas, keep renderer/select-component deltas.
5. Profile: 50-infantry select + move order; verify Process-time spike ≤ ~2ms/frame.

## Open Questions

- None blocking. (Flyer bypass is resolved as D4; batch size stays 8 per D-Non-Goals.)

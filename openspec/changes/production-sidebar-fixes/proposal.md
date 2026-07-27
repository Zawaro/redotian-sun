## Why

A review of the tabbed build-menu / production branch surfaced correctness bugs and hot-path
performance costs in the production and sidebar systems. Units can spawn inside their own factory
when the exit is crowded, one player exiting build mode can unblock every player's production
queue, and the sidebar rebuilds its entire cameo grid up to eight times per frame. Fixing these
now keeps the production pipeline correct before multiplayer and removes avoidable per-frame work.

## What Changes

- **Fix** unit spawning inside factories: when no free exit cell is found within the search radius,
  the fallback spawner no longer returns the factory's own cell; the unit enters the ready-to-spawn
  retry list with a warning instead.
- **Fix** build-mode unblock leaking across players: `build_mode_changed` carries the owning
  `player_id`, and only that player's waiting queues are unblocked.
- **Perf** debounce the sidebar cameo grid: coalesce the many production/prerequisite signals into a
  single deferred rebuild per frame via a dirty flag.
- **Perf** cache the sidebar lookup: `UIUtil.find_sidebar()` memoizes the resolved node instead of
  walking the whole scene tree on every mouse-handler frame.
- **Refactor** derive `EntityData.get_build_time()` from `GlobalRules.build_speed` so the build-speed
  factor has a single source of truth instead of a duplicated constant.
- **Refactor** track the actual deducted amount on each ready-to-place building so a cancel refund
  cannot drift from what was spent.
- **Refactor** rename `SelectionOverlay.SEGMENT_WIDTH_RATIO` to `SEGMENT_PX_PER_UNIT` to match its
  real meaning (pixels per world unit, not a width ratio).

## Capabilities

### New Capabilities
<!-- None: this change fixes and refines existing behavior. -->

### Modified Capabilities
- `production-manager`: build-mode-exit unblock is scoped to the owning player, and a cancelled
  ready-to-place building refunds the exact amount tracked as deducted.
- `production-exit`: when no free exit cell exists near a factory, the unit is not spawned inside the
  building; it enters the ready-to-spawn retry state instead.
- `entity-data`: default build time derives from the game-wide `GlobalRules.build_speed` factor.

## Impact

- `scripts/production/ProductionManager.gd` — exit-cell null handling, player-scoped unblock,
  deducted tracking on ready-to-place entries.
- `scripts/buildings/BuildingManager.gd` — `build_mode_changed` signal gains a `player_id` argument.
- `scripts/ui/Sidebar.gd` — deferred/dirty-flag grid refresh.
- `scripts/core/UIUtil.gd` — cached sidebar lookup.
- `scripts/data/EntityData.gd` — build-time factor sourced from GlobalRules.
- `scripts/ui/SelectionOverlay.gd` — constant rename.
- No packed scenes (`.tscn`) change. The signal signature change is internal (single connection in
  ProductionManager).

## Why

The dock-host-client refactor (PR #52) introduced `RefineryComponent` that was never created as a file, and `DockClientComponent` at 349 lines has timing/retry logic that belongs on `DockHostComponent`. OpenRA's proven architecture shows the host should own queue timing while the client stays thin and reactive. Additionally, no unit tests cover the dock host-client interaction pattern (reservation, queue promotion, timeout handling).

## What Changes

- **Wire** `accepted_resource_categories` from EntityData to DockUnloadComponent via `configure(data)` — empty = accept all, non-empty = exclusive whitelist
- **Simplify** `DockClientComponent` from ~349 lines to ~120 lines by removing:
  - `_refinery_timeout` / `_docking_timeout` / `_queued_timeout` — host manages stale client cleanup
  - `_retry_cooldown` — host signals failure, client retries on next command
  - `_recheck_timer` / `_find_shorter_queue()` — host promotes from queue, client waits
- **Extend** `DockHostComponent` with:
  - `stale_timeout: float` — auto-evict clients that don't complete dock sequence within N seconds
  - Emit `dock_timeout` signal when client is evicted
- **Add** cargo validation in `DockUnloadComponent` using `EntityData.accepted_resource_categories` from the building's entity data (read at configure time)
- **Add** comprehensive unit tests for dock host-client relationship:
  - Request dock when empty → immediate dock
  - Request dock when occupied → queue
  - Queue full → reject
  - Leave dock → promote next in queue
  - Stale client timeout → evict and promote
  - Slot available signal → queued client transitions to docked
  - Dock type filtering (harvest vs repair vs other)
  - Cell reservation/release in SpatialHash

## Capabilities

### New Capabilities
- `dock-host-client`: Complete dock system — DockHostComponent queue management, DockClientComponent reservation flow, DockUnloadComponent cargo handling, cargo validation via accepted_resource_categories

### Modified Capabilities
- `entity-data`: Keep `accepted_resource_categories` (passed to DockUnloadComponent via `configure`) and `dock_unload: bool`
- `resource-harvesting`: Update DockHostComponent and DockClientComponent requirements to reflect the simplified timing model; add cargo validation and the harvester state-machine (DELIVERING/HIBERNATE/unblock) requirement

## Impact

- **Scripts**: `EntityData.gd`, `DockClientComponent.gd`, `DockHostComponent.gd`, `DockUnloadComponent.gd`, `EntityFactory.gd`, `HarvestComponent.gd`
- **Resources**: `resources/entities/structures/gdi/gdi_refinery.tres` (add `refinery = true`)
- **Tests**: `test/unit/test_dock_host_component.gd`, `test/unit/test_dock_client_component.gd`, `test/unit/test_harvest_dock.gd` — expand with comprehensive interaction tests
- **Scenes**: None — component-based architecture, no scene changes needed

## Follow-up Hardening (same branch)

A ponytail/caveman review of the refactor surfaced bugs and dead code, fixed on this branch:

**Correctness**
- Fixed a synchronous-recursion crash: full harvester + no reachable refinery re-sought docks in the same callstack via `dock_slot_failed`. Now schedules a `DELIVER_RETRY` cooldown instead.
- `set_target_refinery` (player-ordered dock) now enters `DELIVERING` so the undock/failed/cancelled handlers resume the loop — previously left the harvester stuck.
- `DockClient.cancel()` fully aborts docking from any sub-state (leave slot/queue + reset). `cancel_harvest` uses it, so a player move order mid-dock reliably reaches `IDLE` instead of drifting back or unloading remotely.
- `_begin_unload` sets `UNLOADING` only after validating the host; `on_dock_undocked` clears `_queued_host`; MOVING retry guards with `is_instance_valid`.
- Stale timer resets on arrival so a long approach no longer trips eviction.

**Behavior**
- Added `HIBERNATE` state: an exhausted, empty harvester periodically re-scans (`HIBERNATE_INTERVAL`) and auto-resumes, instead of going `IDLE` (now reserved for explicit player stop).
- Added dock-unblock: a harvester hibernating on a dock cell steps off to a free wait cell.

**Removed as dead / over-engineered**
- `refinery: bool` flag (no runtime readers), `refinery_storage` (no readers), `on_dock_timeout()` client handler + `dock_slot_reserved` signal (redundant with `docker_undocked`), `State.SEEKING`, `const RETRY_COOLDOWN`, ~24 debug `print()` blocks, and the always-null transport lookup in DockUnloadComponent.
- `max_queue_length` cap dropped — the queue is unbounded; occupancy penalty does soft load-balancing. (Re-adding a cap requires restoring the "rejected → try next host" fallback.)
